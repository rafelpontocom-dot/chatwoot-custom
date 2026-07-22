# rubocop:disable Metrics/ClassLength
class Api::V1::Accounts::KanbanBoards::CardsController < Api::V1::Accounts::BaseController
  before_action :fetch_kanban_board
  before_action :authorize_kanban_board_show
  before_action :fetch_manual_card_records, only: [:create_manual]
  before_action :fetch_kanban_card, only: [:show, :update, :destroy, :reorder, :timeline]
  before_action :fetch_archived_kanban_card, only: [:restore]
  before_action :fetch_kanban_stage, only: [:update]
  before_action :authorize_mutation_target, only: [:show, :update, :destroy, :reorder, :restore, :timeline]

  def show
    render_card
  end

  def create_manual
    @kanban_card = KanbanCards::CreateManualCardService.new(
      account: Current.account,
      user: Current.user,
      kanban_board: @kanban_board,
      kanban_stage: @kanban_stage,
      contact: @contact,
      inbox: @inbox,
      subject: manual_card_params[:subject]
    ).perform!

    render :create_manual, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_manual_creation_error(e)
  end

  def archived
    cards = @kanban_board
            .kanban_cards
            .where(active: false)
            .where.not(archived_at: nil)
            .includes(:kanban_stage, :contact, :inbox, :conversation, :archived_by)
            .order(archived_at: :desc, id: :desc)
            .select { |card| policy(card).restore? }

    render json: cards.map { |card| archived_card_payload(card) }
  end

  def bulk
    authorize @kanban_board, :bulk?
    @bulk_cards = bulk_cards
    updated_count = run_bulk_update

    render json: { updated_count: updated_count, failed_count: 0, errors: [] }
  rescue ActiveRecord::RecordInvalid => e
    render json: {
      updated_count: 0,
      failed_count: @bulk_cards&.length || 0,
      errors: Array(@bulk_cards).map do |card|
        { card_id: card.id, messages: e.record.errors.full_messages }
      end,
      message: e.record.errors.full_messages.to_sentence
    }, status: :unprocessable_entity
  end

  def update
    update_kanban_card
  rescue ActiveRecord::StaleObjectError
    render_stale_card
  end

  def reorder
    reorder_kanban_card
  rescue ActiveRecord::StaleObjectError
    render_stale_card
  end

  def restore
    @kanban_card.restore!(actor: Current.user)
    render_card
  end

  def timeline
    render json: @kanban_card.kanban_card_events.order(occurred_at: :asc, id: :asc).map { |event| timeline_event_payload(event) }
  end

  def destroy
    destroy_kanban_card
  end

  private

  def fetch_kanban_board
    @kanban_board = policy_scope(KanbanBoard).find(params[:kanban_board_id])
  end

  def authorize_kanban_board_show
    authorize @kanban_board, :show?
  end

  def fetch_kanban_card
    @kanban_card = @kanban_board.kanban_cards.active.joins(:kanban_stage).merge(KanbanStage.active).find(params[:id])
  end

  def fetch_archived_kanban_card
    @kanban_card = @kanban_board.kanban_cards.where(active: false).joins(:kanban_stage).merge(KanbanStage.active).find(params[:id])
  end

  def authorize_mutation_target
    policy_action = action_name_policy
    authorize @kanban_card, policy_action
    authorize_update_permissions if policy_action == :update?
  end

  def authorize_update_permissions
    authorize @kanban_card, :assign? if card_params.key?(:owner_id)
    authorize @kanban_card, :close? if close_permission_required?
  end

  def close_permission_required?
    close_status_update?(card_params) || @kanban_stage&.category&.in?(%w[won lost])
  end

  def fetch_kanban_stage
    stage_id = card_params[:kanban_stage_id]
    return @kanban_stage = @kanban_card.kanban_stage if stage_id.blank?

    @kanban_stage = @kanban_board.kanban_stages.active.find(stage_id)
  end

  def fetch_manual_card_records
    @kanban_stage = @kanban_board.kanban_stages.find(manual_card_params[:kanban_stage_id])
    @contact = Current.account.contacts.find(manual_card_params[:contact_id])
    @inbox = Current.account.inboxes.find(manual_card_params[:inbox_id])
  end

  # rubocop:disable Metrics/MethodLength
  def card_params
    params.require(:card).permit(
      :kanban_stage_id,
      :position,
      :subject,
      :description,
      :starts_at,
      :due_at,
      :owner_id,
      :next_action_type,
      :next_action_at,
      :next_action_note,
      :next_action_completed_at,
      :won_at,
      :lost_at,
      :lost_reason,
      :amount_cents,
      :amount_currency,
      :expected_close_date,
      :lock_version,
      custom_field_values: {},
      labels: []
    )
  end
  # rubocop:enable Metrics/MethodLength

  def manual_card_params
    params.require(:card).permit(:kanban_stage_id, :contact_id, :inbox_id, :subject)
  end

  def bulk_params
    params.permit(:operation, :owner_id, :stage_id, :lost_reason, card_ids: [])
  end

  def run_bulk_update
    authorize_bulk_cards!(@bulk_cards)

    KanbanCards::BulkUpdateService.new(
      board: @kanban_board,
      cards: @bulk_cards,
      user: Current.user,
      operation: bulk_params[:operation],
      options: bulk_params.slice(:owner_id, :stage_id, :lost_reason)
    ).perform!
  end

  def bulk_cards
    card_ids = Array(bulk_params[:card_ids]).map(&:to_i).uniq
    raise ActiveRecord::RecordNotFound if card_ids.blank? || card_ids.length > KanbanCards::BulkUpdateService::MAX_CARDS

    cards = bulk_cards_scope.where(id: card_ids).includes(:kanban_stage, :contact, :inbox, :conversation).to_a
    raise ActiveRecord::RecordNotFound unless cards.length == card_ids.length

    cards.sort_by { |card| card_ids.index(card.id) }
  end

  def bulk_cards_scope
    bulk_params[:operation] == 'restore' ? @kanban_board.kanban_cards.where(active: false) : @kanban_board.kanban_cards.active
  end

  def authorize_bulk_cards!(cards)
    policy_action = case bulk_params[:operation]
                    when 'archive' then :destroy?
                    when 'restore' then :restore?
                    when 'assign_owner' then :assign?
                    when 'mark_won', 'mark_lost' then :close?
                    when 'move_stage' then :reorder?
                    else :update?
                    end
    cards.each { |card| authorize card, policy_action }
  end

  def render_manual_creation_error(error)
    duplicate = possible_duplicate_card(error)
    raise error unless duplicate

    render json: {
      message: error.record.errors.full_messages.to_sentence,
      code: 'possible_duplicate',
      duplicate_card: {
        id: duplicate.id,
        subject: duplicate.subject,
        stage_id: duplicate.kanban_stage_id,
        stage_name: duplicate.kanban_stage.name
      }
    }, status: :unprocessable_entity
  end

  def possible_duplicate_card(error)
    return unless error.record.errors.full_messages.any? { |message| message.include?('Manual opportunity with this subject already exists') }

    @kanban_board.kanban_cards.manual.active.find_by(
      contact: @contact,
      inbox: @inbox,
      normalized_subject: manual_card_params[:subject].to_s.strip.gsub(/\s+/, ' ').downcase
    )
  end

  def action_name_policy
    "#{action_name}?".to_sym
  end

  def update_kanban_card
    return render_stale_card unless card_version_current?(card_params[:lock_version])

    invalid_label_titles = persist_card_update

    return render_unknown_labels(invalid_label_titles) if invalid_label_titles.present?

    dispatch_kanban_card_event(Events::Types::KANBAN_CARD_UPDATED)
    render_card
  end

  def persist_card_update
    invalid_label_titles = []

    KanbanCard.transaction do
      invalid_label_titles = unknown_label_titles if labels_param_present? && unknown_label_titles.present?
      raise ActiveRecord::Rollback if invalid_label_titles.present?

      reorder_card_if_needed
      @kanban_card.update!(stable_card_update_params)
      @kanban_card.update_labels(label_titles) if labels_param_present?
    end

    invalid_label_titles
  end

  def reorder_card_if_needed
    return unless stable_card_move_params?

    @kanban_card.reorder_to_position!(
      kanban_stage: @kanban_stage,
      position: card_params[:position] || target_card_position(@kanban_stage)
    )
  end

  def reorder_kanban_card
    return render_stale_card unless card_version_current?(reorder_card_params[:lock_version])

    source_stage_id = @kanban_card.kanban_stage_id
    target_stage = target_card_stage_for_reorder
    return render_missing_lost_reason if target_stage.category == 'lost' && reorder_card_params[:lost_reason].blank?

    KanbanCard.transaction do
      @kanban_card.reorder_to_position!(
        kanban_stage: target_stage,
        position: reorder_card_params[:position] || @kanban_card.position
      )
      @kanban_card.update!(reorder_update_attributes(target_stage))
    end

    dispatch_kanban_card_reordered_event(source_stage_id)
    render_card
  rescue ActiveRecord::RecordInvalid => e
    render_assisted_move_fields(e.record)
  end

  def reorder_update_attributes(target_stage)
    stage_category_attributes(target_stage, reorder_card_params[:lost_reason]).tap do |attributes|
      next unless reorder_card_params.key?(:custom_field_values)

      attributes[:custom_field_values] = @kanban_card.custom_field_values.to_h.merge(reorder_card_params[:custom_field_values].to_h)
    end
  end

  def destroy_kanban_card
    stage_id = @kanban_card.kanban_stage_id
    @kanban_card.archive!(actor: Current.user)

    dispatch_kanban_card_event(Events::Types::KANBAN_CARD_DELETED, stage_id: stage_id)
    head :no_content
  end

  def next_card_position(kanban_stage)
    @kanban_board.kanban_cards.active.where(kanban_stage: kanban_stage).maximum(:position).to_i + 1
  end

  def target_card_position(kanban_stage)
    return @kanban_card.position if kanban_stage == @kanban_card.kanban_stage

    next_card_position(kanban_stage)
  end

  # rubocop:disable Metrics/MethodLength
  def stable_card_update_params
    card_params
      .slice(
        :subject,
        :description,
        :starts_at,
        :due_at,
        :owner_id,
        :next_action_type,
        :next_action_at,
        :next_action_note,
        :next_action_completed_at,
        :won_at,
        :lost_at,
        :lost_reason,
        :amount_cents,
        :amount_currency,
        :expected_close_date,
        :custom_field_values
      )
      .tap do |permitted_params|
        apply_target_stage_category!(permitted_params) if card_params[:kanban_stage_id].present?
        normalize_sales_update_params!(permitted_params)
      end
  end
  # rubocop:enable Metrics/MethodLength

  def normalize_sales_update_params!(permitted_params)
    validate_account_user_id!(:owner, permitted_params[:owner_id]) if permitted_params.key?(:owner_id)
    return unless close_status_update?(permitted_params)

    permitted_params[:closed_by_id] = Current.user.id
    normalize_won_update_params!(permitted_params)
    normalize_lost_update_params!(permitted_params)
  end

  def close_status_update?(permitted_params)
    permitted_params[:won_at].present? || permitted_params[:lost_at].present?
  end

  def normalize_won_update_params!(permitted_params)
    return unless permitted_params.key?(:won_at) && !permitted_params.key?(:lost_at)

    permitted_params[:lost_at] = nil
    permitted_params[:lost_reason] = nil unless permitted_params.key?(:lost_reason)
  end

  def normalize_lost_update_params!(permitted_params)
    return unless permitted_params.key?(:lost_at) && !permitted_params.key?(:won_at)

    permitted_params[:won_at] = nil
  end

  def validate_account_user_id!(field_name, user_id)
    return if user_id.blank?
    return if Current.account.account_users.exists?(user_id: user_id)

    @kanban_card.errors.add(field_name, :invalid)
    raise ActiveRecord::RecordInvalid, @kanban_card
  end

  def labels_param_present?
    params.require(:card).key?(:labels)
  end

  def label_titles
    @label_titles ||= Array(card_params[:labels]).uniq
  end

  def account_label_titles
    @account_label_titles ||= Current.account.labels.where(title: label_titles).pluck(:title)
  end

  def unknown_label_titles
    @unknown_label_titles ||= label_titles - account_label_titles
  end

  def render_unknown_labels(label_titles)
    render json: { error: "Unknown labels: #{label_titles.join(', ')}" }, status: :unprocessable_entity
  end

  def stable_card_move_params?
    card_params[:kanban_stage_id].present? || card_params[:position].present?
  end

  def target_card_stage_for_reorder
    stage_id = reorder_card_params[:kanban_stage_id]
    return @kanban_card.kanban_stage if stage_id.blank?

    @kanban_board.kanban_stages.active.find(stage_id)
  end

  def reorder_card_params
    @reorder_card_params ||= params.require(:card).permit(:kanban_stage_id, :position, :lost_reason, :lock_version, custom_field_values: {})
  end

  def card_version_current?(client_version)
    client_version.blank? || client_version.to_i == @kanban_card.lock_version
  end

  def render_stale_card
    @kanban_card.reload
    card_payload = JSON.parse(
      render_to_string(
        partial: 'api/v1/accounts/kanban_boards/card',
        formats: [:json],
        locals: { card: @kanban_card, stable_card: true }
      )
    )
    render json: {
      code: 'stale_object',
      message: 'This opportunity was changed by another user. Review the current data before saving again.',
      card: card_payload
    }, status: :conflict
  end

  def apply_target_stage_category!(permitted_params)
    permitted_params.merge!(stage_category_attributes(@kanban_stage, permitted_params[:lost_reason]))
  end

  def stage_category_attributes(target_stage, lost_reason)
    case target_stage.category
    when 'won'
      { won_at: Time.current, lost_at: nil, lost_reason: nil, closed_by_id: Current.user.id }
    when 'lost'
      { won_at: nil, lost_at: Time.current, lost_reason: lost_reason, closed_by_id: Current.user.id }
    else
      { won_at: nil, lost_at: nil, lost_reason: nil, closed_by_id: nil }
    end
  end

  def render_missing_lost_reason
    render json: {
      message: 'Lost reason is required before moving this opportunity.',
      missing_fields: ['lost_reason']
    }, status: :unprocessable_entity
  end

  def render_assisted_move_fields(card)
    missing_fields = card.missing_required_custom_field_keys
    raise ActiveRecord::RecordInvalid, card if missing_fields.blank?

    render json: {
      message: 'Complete the required fields before moving this opportunity.',
      missing_fields: missing_fields,
      field_definitions: @kanban_board.custom_field_definitions.select { |definition| missing_fields.include?(definition['key']) }
    }, status: :unprocessable_entity
  end

  def timeline_event_payload(event)
    {
      id: event.id,
      event_type: event.event_type,
      occurred_at: event.occurred_at.iso8601,
      changes: event.change_set,
      actor: event.actor && { id: event.actor_id, type: event.actor_type, name: event.actor.try(:name) },
      metadata: event.metadata
    }
  end

  def archived_card_payload(card)
    {
      id: card.id,
      subject: card.subject,
      stage_id: card.kanban_stage_id,
      stage_name: card.kanban_stage.name,
      contact_name: card.contact.name,
      archived_at: card.archived_at.iso8601,
      archived_by: card.archived_by && { id: card.archived_by_id, name: card.archived_by.name }
    }
  end

  def dispatch_kanban_card_event(event_name, stage_id: @kanban_card.kanban_stage_id)
    Rails.configuration.dispatcher.dispatch(
      event_name,
      Time.zone.now,
      account_id: @kanban_card.account_id,
      board_id: @kanban_card.kanban_board_id,
      stage_id: stage_id,
      card_id: @kanban_card.id,
      conversation_id: @kanban_card.conversation_id
    )
  end

  def dispatch_kanban_card_reordered_event(source_stage_id)
    Rails.configuration.dispatcher.dispatch(
      Events::Types::KANBAN_CARD_REORDERED,
      Time.zone.now,
      account_id: @kanban_card.account_id,
      board_id: @kanban_card.kanban_board_id,
      card_id: @kanban_card.id,
      conversation_id: @kanban_card.conversation_id,
      source_stage_id: source_stage_id,
      target_stage_id: @kanban_card.kanban_stage_id
    )
  end

  def render_card
    render partial: 'api/v1/accounts/kanban_boards/card', formats: [:json], locals: {
      card: @kanban_card,
      stable_card: true
    }
  end
end
# rubocop:enable Metrics/ClassLength
