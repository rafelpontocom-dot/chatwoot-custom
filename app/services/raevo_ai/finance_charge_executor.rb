class RaevoAi::FinanceChargeExecutor
  class InvalidCharge < StandardError; end

  def initialize(integration:, conversation:, command:)
    @integration = integration
    @conversation = conversation
    @action_id = command.fetch(:action_id)
    @board_key = command.fetch(:board_key)
    @charge_key = command.fetch(:charge_key)
    @tax_id = command[:tax_id]
  end

  def perform
    charge = RaevoAi::FinanceCatalog.new(integration: @integration).resolve_charge!(charge_key: @charge_key, board_key: @board_key)
    card = resolved_card
    claim = RaevoAi::CommandRecorder.new(
      integration: @integration,
      action_id: @action_id,
      command_type: 'finance.create_charge',
      payload: command_payload(charge, card)
    ).claim
    return claim.command.result if claim.command.state == 'applied'

    apply_claim!(claim.command, charge, card)
  end

  private

  def resolved_card
    board = RaevoAi::CrmCatalog.new(integration: @integration).resolve_board!(@board_key)
    validate_conversation!

    RaevoAi::CrmCardResolver.new(integration: @integration, conversation: @conversation, board: board).resolve!
  end

  def validate_conversation!
    return if @conversation.account_id == @integration.account_id && @conversation.contact_id.present?

    raise InvalidCharge, 'conversation is not eligible for a charge in this integration account'
  end

  def apply_claim!(claimed_command, charge, card)
    RaevoAiCommand.transaction do
      command = claimed_command.lock!
      command.state == 'applied' ? command.result : apply_pending_command!(command, charge, card)
    end
  end

  def apply_pending_command!(command, charge, card)
    payment = create_payment!(charge, card)
    result = receipt(payment)
    command.update!(state: 'applied', result: result)
    result
  end

  def create_payment!(charge, card)
    attributes = {
      connection: charge[:connection], contact: @conversation.contact, kanban_card: card, actor: nil,
      amount_cents: charge[:amount_cents], billing_type: charge[:billing_type], due_on: charge[:due_on],
      description: charge[:description], currency: charge[:currency], external_reference: external_reference
    }
    case charge[:connection].provider
    when 'manual' then Finance::Manual::CreatePaymentService.new(**attributes).perform
    when 'asaas'
      Finance::Asaas::CreatePaymentService.new(**attributes, cpf_cnpj: configured_tax_id!(charge)).perform
    else raise InvalidCharge, 'configured finance provider is not supported for AI charges'
    end
  end

  def configured_tax_id!(charge)
    value = if charge[:tax_id_source] == 'command'
              @tax_id
            else
              key = charge[:tax_id_attribute]
              key && @conversation.contact.custom_attributes[key]
            end
    normalized = value.to_s.gsub(/\D/, '')
    raise InvalidCharge, 'configured tax id is not available for the contact' unless normalized.length.in?([11, 14])

    normalized
  end

  def external_reference
    @external_reference ||= "raevo-ai-#{Digest::SHA256.hexdigest("#{@integration.id}:#{@action_id}")}"
  end

  def command_payload(charge, card)
    payload = {
      'conversation_id' => @conversation.display_id, 'card_id' => card.id, 'board_key' => @board_key,
      'charge_key' => charge[:key], 'connection_id' => charge[:connection].id, 'amount_cents' => charge[:amount_cents],
      'billing_type' => charge[:billing_type], 'currency' => charge[:currency], 'due_on' => charge[:due_on].iso8601,
      'external_reference' => external_reference
    }
    payload['tax_id_digest'] = Digest::SHA256.hexdigest(configured_tax_id!(charge)) if charge[:connection].provider == 'asaas'
    payload
  end

  def receipt(payment)
    {
      'action_id' => @action_id,
      'status' => 'applied',
      'receipts' => { 'payment' => { 'status' => payment.status, 'payment_id' => payment.id, 'invoice_url' => payment.invoice_url } }
    }
  end
end
