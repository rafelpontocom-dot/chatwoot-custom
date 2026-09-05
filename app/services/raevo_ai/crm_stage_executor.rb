class RaevoAi::CrmStageExecutor
  class LockConflict < StandardError; end
  class InvalidCard < StandardError; end

  def initialize(integration:, card:, command:)
    @integration = integration
    @card = card
    @action_id = command.fetch(:action_id)
    @board_key = command.fetch(:board_key)
    @event_key = command.fetch(:event_key)
    @expected_lock_version = command.fetch(:expected_lock_version)
  end

  def perform
    catalog = RaevoAi::CrmCatalog.new(integration: @integration)
    board = catalog.resolve_board!(@board_key)
    validate_card!(board)
    claim = RaevoAi::CommandRecorder.new(
      integration: @integration,
      action_id: @action_id,
      command_type: 'crm.move_stage',
      payload: command_payload
    ).claim

    return claim.command.result if claim.command.state == 'applied'

    apply_claim!(claim.command, catalog, board)
  end

  private

  def validate_card!(board)
    return if @card.account_id == @integration.account_id && @card.kanban_board_id == board.id

    raise InvalidCard, 'card does not belong to the configured board in the integration account'
  end

  def apply_claim!(claimed_command, catalog, board)
    RaevoAiCommand.transaction do
      command = claimed_command.lock!
      command.state == 'applied' ? command.result : apply_pending_command!(command, catalog, board)
    end
  end

  def apply_pending_command!(command, catalog, board)
    @card.reload
    raise LockConflict, 'card lock_version does not match the expected version' unless @card.lock_version == @expected_lock_version

    target_stage = catalog.resolve_stage!(@board_key, @event_key, current_stage_id: @card.kanban_stage_id)
    KanbanCards::TransferCardService.new(card: @card, target_board: board, target_stage: target_stage, actor: nil).perform!

    result = receipt(target_stage)
    command.update!(state: 'applied', result: result)
    result
  end

  def command_payload
    {
      'card_id' => @card.id,
      'board_key' => @board_key,
      'event_key' => @event_key,
      'expected_lock_version' => @expected_lock_version
    }
  end

  def receipt(target_stage)
    {
      'action_id' => @action_id,
      'status' => 'applied',
      'receipts' => {
        'stage' => { 'status' => 'applied', 'stage_id' => target_stage.id }
      }
    }
  end
end
