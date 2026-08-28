class Forms::CreatePublicOpportunityService
  OPPORTUNITY_POLICIES = %w[create_new reuse_open].freeze

  def initialize(submission:)
    @submission = submission
  end

  def perform
    return if destination.blank? || contact.blank? || sensitive_health_form?

    card = KanbanCard.transaction do
      validate_destination!
      card = matching_card || create_card!
      submission.update!(kanban_card: card, metadata: success_metadata)
      mapping_result = Forms::MapSubmissionToOpportunityService.new(
        submission: submission,
        kanban_card: card
      ).perform
      submission.update!(metadata: success_metadata(mapping_result))
      card
    end

    dispatch_card_created_event if @created_card
    card
  rescue DestinationError, ActiveRecord::RecordInvalid
    record_failure
    nil
  end

  private

  DestinationError = Class.new(StandardError)

  attr_reader :submission

  delegate :account, :contact, to: :submission

  def destination
    @destination ||= submission.form_template_version.schema.fetch('crm_destination', {}).to_h.stringify_keys
  end

  def board
    @board ||= KanbanBoard.active.find_by(account_id: account.id, id: destination['kanban_board_id'])
  end

  def stage
    @stage ||= board&.kanban_stages&.active&.find_by(id: destination['kanban_stage_id'])
  end

  def inbox
    @inbox ||= account.inboxes.find_by(id: destination['inbox_id'])
  end

  def opportunity_policy
    destination.fetch('opportunity_policy', 'reuse_open')
  end

  def validate_destination!
    raise DestinationError if board.blank? || stage.blank? || inbox.blank?
    raise DestinationError unless stage.kanban_board_id == board.id && board.inbox_allowed?(inbox)
    raise DestinationError unless OPPORTUNITY_POLICIES.include?(opportunity_policy)
  end

  def matching_card
    return if opportunity_policy == 'create_new'

    KanbanCard.open_opportunities.where(account: account, contact: contact, kanban_board: board).order(created_at: :desc, id: :desc).first
  end

  def create_card!
    stage.lock!
    KanbanCard.lock_active_cards_for_stages!(board, [stage.id])
    KanbanCard.where(kanban_board: board, kanban_stage: stage).active.update_all( # rubocop:disable Rails/SkipsModelValidations
      ['position = position + 1, updated_at = ?', Time.current]
    )
    @created_card = KanbanCard.create!(
      account: account,
      kanban_board: board,
      kanban_stage: stage,
      contact: contact,
      inbox: inbox,
      subject: opportunity_subject,
      origin: 'manual',
      position: 1,
      active: true
    )
  end

  def opportunity_subject
    subject = "#{submission.form_template_version.form_template.name} - #{contact.name}"
    return subject if opportunity_policy == 'reuse_open'

    "#{subject} ##{submission.id}"
  end

  def success_metadata(mapping_result = nil)
    metadata = submission.metadata.merge('crm_destination' => { 'status' => 'linked' })
    return metadata if mapping_result.nil? || mapping_result.status == 'not_configured'

    metadata.merge('kanban_card_mapping' => { 'status' => mapping_result.status })
  end

  def record_failure
    submission.update_columns( # rubocop:disable Rails/SkipsModelValidations
      metadata: submission.metadata.merge('crm_destination' => { 'status' => 'failed' }),
      updated_at: Time.current
    )
  end

  def sensitive_health_form?
    submission.form_template_version.form_template.access_classification == 'sensitive_health'
  end

  def dispatch_card_created_event
    Rails.configuration.dispatcher.dispatch(
      Events::Types::KANBAN_CARD_CREATED,
      Time.zone.now,
      account_id: @created_card.account_id,
      board_id: @created_card.kanban_board_id,
      stage_id: @created_card.kanban_stage_id,
      card_id: @created_card.id,
      conversation_id: @created_card.conversation_id
    )
  end
end
