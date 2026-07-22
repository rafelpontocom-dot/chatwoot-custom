class Api::V1::Accounts::KanbanBoards::SettingsController < Api::V1::Accounts::BaseController
  before_action :fetch_kanban_board
  before_action :authorize_kanban_board

  def show; end

  def update
    return render_stale_settings if stale_settings?
    return render_data_loss_confirmation if removed_field_usage.present? && !data_loss_confirmed?

    ActiveRecord::Base.transaction do
      @kanban_board.update!(settings_params.except(:visible_user_ids, :allowed_inbox_ids))
      replace_memberships!
      replace_inboxes!
    end

    dispatch_kanban_board_event
    render :show
  end

  def import_existing_conversations
    ignore_groups = ActiveModel::Type::Boolean.new.cast(params[:ignore_groups])
    service = KanbanCards::ImportExistingConversationsService.new(
      account: Current.account,
      kanban_board: @kanban_board,
      ignore_groups: ignore_groups
    )

    KanbanCards::ImportExistingConversationsJob.perform_later(Current.account.id, @kanban_board.id, ignore_groups: ignore_groups)

    render json: {
      status: 'accepted',
      enqueued: true,
      estimated_count: service.estimated_count
    }, status: :accepted
  end

  private

  def fetch_kanban_board
    @kanban_board = KanbanBoard.active.where(account_id: Current.account.id).find(params[:kanban_board_id])
  end

  def authorize_kanban_board
    authorize @kanban_board, :update?
  end

  def stale_settings?
    settings_params[:lock_version].present? && settings_params[:lock_version].to_i != @kanban_board.lock_version
  end

  def render_stale_settings
    render json: {
      code: 'stale_settings',
      message: 'These funnel settings changed in another session. Reload before saving.',
      lock_version: @kanban_board.lock_version
    }, status: :conflict
  end

  def data_loss_confirmed?
    ActiveModel::Type::Boolean.new.cast(params[:confirm_data_loss])
  end

  def render_data_loss_confirmation
    render json: {
      code: 'custom_field_data_loss_confirmation_required',
      affected_fields: removed_field_usage
    }, status: :unprocessable_entity
  end

  # rubocop:disable Metrics/MethodLength
  def settings_params
    params.require(:kanban_board).permit(
      :name,
      :description,
      :visibility_mode,
      :inbox_scope_mode,
      :auto_create_cards_from_conversations,
      :lock_version,
      visible_user_ids: [],
      allowed_inbox_ids: [],
      next_action_types: [],
      lost_reason_options: [],
      compact_card_field_keys: [],
      custom_field_sections: [:key, :label, :color, { groups: [:key, :label, :color] }],
      stale_stage_thresholds: {},
      custom_field_definitions: [
        :key,
        :label,
        :field_type,
        :formula,
        :formula_result_type,
        :important,
        {
          options: [],
          required_stage_ids: [],
          condition: [:field_key, :equals],
          layout: [:section, :group, :position, :width]
        }
      ]
    )
  end
  # rubocop:enable Metrics/MethodLength

  def removed_field_usage
    return [] unless settings_params.key?(:custom_field_definitions)

    current_keys = @kanban_board.configured_custom_field_definitions.pluck('key')
    incoming_keys = Array(settings_params[:custom_field_definitions]).pluck(:key).map(&:to_s)
    @kanban_board.custom_field_usage(current_keys - incoming_keys).filter_map do |key, count|
      { key: key, count: count } if count.positive?
    end
  end

  def replace_memberships!
    return unless settings_params.key?(:visible_user_ids) || @kanban_board.all_agents?

    user_ids = normalized_ids(settings_params[:visible_user_ids])
    validate_account_user_ids!(user_ids)
    KanbanBoardMember.where(kanban_board_id: @kanban_board.id).delete_all
    return if @kanban_board.all_agents? || user_ids.blank?

    user_ids.each do |user_id|
      KanbanBoardMember.create!(account: Current.account, kanban_board: @kanban_board, user_id: user_id)
    end
  end

  def replace_inboxes!
    return unless settings_params.key?(:allowed_inbox_ids) || @kanban_board.all_inboxes?

    inbox_ids = normalized_ids(settings_params[:allowed_inbox_ids])
    validate_account_inbox_ids!(inbox_ids)
    KanbanBoardInbox.where(kanban_board_id: @kanban_board.id).delete_all
    return if @kanban_board.all_inboxes? || inbox_ids.blank?

    inbox_ids.each do |inbox_id|
      KanbanBoardInbox.create!(account: Current.account, kanban_board: @kanban_board, inbox_id: inbox_id)
    end
  end

  def normalized_ids(ids)
    Array(ids).filter_map(&:presence).map(&:to_i).uniq
  end

  def validate_account_user_ids!(user_ids)
    return if user_ids.blank?

    valid_user_count = AccountUser.where(account_id: Current.account.id, user_id: user_ids).select(:user_id).distinct.count
    return if valid_user_count == user_ids.length

    raise ActiveRecord::RecordInvalid, @kanban_board
  end

  def validate_account_inbox_ids!(inbox_ids)
    return if inbox_ids.blank?

    valid_inbox_count = Inbox.where(account_id: Current.account.id, id: inbox_ids).count
    return if valid_inbox_count == inbox_ids.length

    raise ActiveRecord::RecordInvalid, @kanban_board
  end

  def dispatch_kanban_board_event
    Rails.configuration.dispatcher.dispatch(
      Events::Types::KANBAN_BOARD_UPDATED,
      Time.zone.now,
      account_id: @kanban_board.account_id,
      board_id: @kanban_board.id
    )
  end
end
