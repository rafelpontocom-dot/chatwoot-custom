class RaevoAi::CrmOpportunityExecutor
  class InvalidConversation < StandardError; end

  def initialize(integration:, conversation:, command:)
    @integration = integration
    @conversation = conversation
    @action_id = command.fetch(:action_id)
    @board_key = command.fetch(:board_key)
  end

  def perform
    catalog = RaevoAi::CrmCatalog.new(integration: @integration)
    board = catalog.resolve_board!(@board_key)
    initial_stage = catalog.resolve_initial_stage!(@board_key)
    validate_conversation!(board)

    claim = RaevoAi::CommandRecorder.new(
      integration: @integration,
      action_id: @action_id,
      command_type: 'crm.ensure_opportunity',
      payload: command_payload
    ).claim

    return claim.command.result if claim.command.state == 'applied'

    apply_claim!(claim.command, board, initial_stage)
  end

  private

  def validate_conversation!(board)
    unless @conversation.account_id == @integration.account_id && @conversation.contact_id.present? && @conversation.inbox_id.present?
      raise InvalidConversation, 'conversation is not eligible for an opportunity in this integration account'
    end
    return if board.inbox_allowed?(@conversation.inbox_id)

    raise InvalidConversation, 'conversation inbox is not allowed by the configured board'
  end

  def apply_claim!(claimed_command, board, initial_stage)
    RaevoAiCommand.transaction do
      command = claimed_command.lock!
      command.state == 'applied' ? command.result : apply_pending_command!(command, board, initial_stage)
    end
  end

  def apply_pending_command!(command, board, initial_stage)
    @conversation = Conversation.lock.find(@conversation.id)
    status = existing_opportunity_status(board) || create_opportunity!(board, initial_stage)

    result = receipt(status)
    command.update!(state: 'applied', result: result)
    result
  end

  def existing_opportunity_status(board)
    cards = board.kanban_cards.active.where(account_id: @integration.account_id, conversation_id: @conversation.id).to_a
    raise RaevoAi::CrmCardResolver::AmbiguousCard, 'multiple active cards are linked to the conversation' if cards.many?

    'already_exists' if cards.one?
  end

  def create_opportunity!(board, initial_stage)
    initial_stage.lock!
    KanbanCard.lock_active_cards_for_stages!(board, [initial_stage.id])
    KanbanCard.where(kanban_board: board, kanban_stage: initial_stage).active.update_all( # rubocop:disable Rails/SkipsModelValidations
      ['position = position + 1, updated_at = ?', Time.current]
    )

    card = KanbanCard.create!(
      account: @integration.account,
      kanban_board: board,
      kanban_stage: initial_stage,
      contact: @conversation.contact,
      inbox: @conversation.inbox,
      conversation: @conversation,
      subject: default_subject,
      origin: 'conversation',
      position: 1,
      active: true
    )
    dispatch_card_created_event(card)
    'created'
  end

  def default_subject
    "#{contact_display_name} - #{inbox_display_name}"
  end

  def contact_display_name
    @conversation.contact.name.presence || "Contact ##{@conversation.contact_id}"
  end

  def inbox_display_name
    @conversation.inbox.name.presence || "Inbox ##{@conversation.inbox_id}"
  end

  def dispatch_card_created_event(card)
    Rails.configuration.dispatcher.dispatch(
      Events::Types::KANBAN_CARD_CREATED,
      Time.zone.now,
      account_id: card.account_id,
      board_id: card.kanban_board_id,
      stage_id: card.kanban_stage_id,
      card_id: card.id,
      conversation_id: card.conversation_id
    )
  end

  def command_payload
    { 'conversation_id' => @conversation.display_id, 'board_key' => @board_key }
  end

  def receipt(status)
    {
      'action_id' => @action_id,
      'status' => 'applied',
      'receipts' => { 'opportunity' => { 'status' => status } }
    }
  end
end
