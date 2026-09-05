class RaevoAi::CrmLabelExecutor
  class LockConflict < StandardError; end
  class InvalidCard < StandardError; end

  def initialize(integration:, card:, command:)
    @integration = integration
    @card = card
    @action_id = command.fetch(:action_id)
    @board_key = command.fetch(:board_key)
    @expected_lock_version = command.fetch(:expected_lock_version)
    @label = command.fetch(:label)
  end

  def perform
    catalog = RaevoAi::CrmCatalog.new(integration: @integration)
    board = catalog.resolve_board!(@board_key)
    validate_card!(board)
    label = catalog.resolve_label!(@board_key, @label)
    claim = RaevoAi::CommandRecorder.new(
      integration: @integration,
      action_id: @action_id,
      command_type: 'crm.add_label',
      payload: command_payload
    ).claim

    return claim.command.result if claim.command.state == 'applied'

    apply_claim!(claim.command, label)
  end

  private

  def validate_card!(board)
    return if @card.account_id == @integration.account_id && @card.kanban_board_id == board.id

    raise InvalidCard, 'card does not belong to the configured board in the integration account'
  end

  def apply_claim!(claimed_command, label)
    RaevoAiCommand.transaction do
      command = claimed_command.lock!
      command.state == 'applied' ? command.result : apply_pending_command!(command, label)
    end
  end

  def apply_pending_command!(command, label)
    @card.reload
    raise LockConflict, 'card lock_version does not match the expected version' unless @card.lock_version == @expected_lock_version

    @card.add_labels([label])
    result = receipt(label)
    command.update!(state: 'applied', result: result)
    result
  end

  def command_payload
    {
      'card_id' => @card.id,
      'board_key' => @board_key,
      'expected_lock_version' => @expected_lock_version,
      'label' => @label
    }
  end

  def receipt(label)
    {
      'action_id' => @action_id,
      'status' => 'applied',
      'receipts' => {
        'label' => { 'status' => 'applied', 'label' => label }
      }
    }
  end
end
