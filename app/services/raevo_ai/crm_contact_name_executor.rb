class RaevoAi::CrmContactNameExecutor
  class InvalidContact < StandardError; end

  def initialize(integration:, contact:, command:)
    @integration = integration
    @contact = contact
    @action_id = command.fetch(:action_id)
    @name = command.fetch(:name).to_s.strip
  end

  def perform
    validate_contact!
    policy = RaevoAi::CrmCatalog.new(integration: @integration).resolve_contact_name_policy!
    claim = RaevoAi::CommandRecorder.new(
      integration: @integration,
      action_id: @action_id,
      command_type: 'crm.update_contact_name',
      payload: command_payload
    ).claim

    return claim.command.result if claim.command.state == 'applied'

    apply_claim!(claim.command, policy)
  end

  private

  def validate_contact!
    return if @contact.account_id == @integration.account_id && @name.present?

    raise InvalidContact, 'contact does not belong to the integration account or name is blank'
  end

  def apply_claim!(claimed_command, policy)
    RaevoAiCommand.transaction do
      command = claimed_command.lock!
      command.state == 'applied' ? command.result : apply_pending_command!(command, policy)
    end
  end

  def apply_pending_command!(command, policy)
    @contact.reload
    updated = policy[:overwrite] == 'always' || @contact.name.blank?
    @contact.update!(name: @name) if updated

    result = receipt(updated)
    command.update!(state: 'applied', result: result)
    result
  end

  def command_payload
    { 'contact_id' => @contact.id, 'name' => @name }
  end

  def receipt(updated)
    {
      'action_id' => @action_id,
      'status' => 'applied',
      'receipts' => {
        'contact_name' => { 'status' => updated ? 'applied' : 'skipped', 'name' => @contact.name }
      }
    }
  end
end
