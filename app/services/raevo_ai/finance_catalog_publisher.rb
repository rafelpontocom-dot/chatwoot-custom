class RaevoAi::FinanceCatalogPublisher
  class InvalidCatalog < StandardError; end

  def initialize(integration:)
    @integration = integration
  end

  def publish!(charge_key:, board_key:, provider_connection_id:, amount_cents:, billing_type:, currency:, due_in_days:,
               tax_id_source:, description: nil, tax_id_attribute: nil)
    raise InvalidCatalog, 'integration must be inactive while publishing the finance catalog' if @integration.enabled?

    normalized_key = charge_key.to_s.strip
    normalized_board_key = board_key.to_s.strip
    raise InvalidCatalog, 'charge_key is invalid' unless normalized_key.match?(/\A[a-z][a-z0-9_]*\z/)
    unless @integration.settings.dig('crm', 'boards', normalized_board_key, 'board_id').to_i.positive?
      raise InvalidCatalog, 'board is not published in the CRM catalog'
    end

    setting = FinanceModuleSetting.find_by(account: @integration.account)
    raise InvalidCatalog, 'finance module is not enabled for this tenant' unless setting&.enabled?

    connection = @integration.account.finance_provider_connections.find_by(id: positive_integer(provider_connection_id))
    raise InvalidCatalog, 'finance connection is not connected' if connection.blank? || connection.status != 'connected'

    normalized_amount = positive_integer(amount_cents)
    normalized_due_days = non_negative_integer(due_in_days)
    normalized_billing_type = billing_type.to_s
    normalized_currency = currency.to_s.upcase
    normalized_tax_id_source = tax_id_source.to_s
    raise InvalidCatalog, 'amount is invalid' if normalized_amount.blank?
    raise InvalidCatalog, 'billing type is invalid' unless normalized_billing_type.in?(FinancePayment::BILLING_TYPES)
    raise InvalidCatalog, 'currency is invalid' unless normalized_currency.match?(/\A[A-Z]{3}\z/)
    raise InvalidCatalog, 'due date policy is invalid' if normalized_due_days.blank?
    raise InvalidCatalog, 'tax id source is invalid' unless normalized_tax_id_source.in?(%w[contact_attribute command])
    if normalized_tax_id_source == 'contact_attribute' && tax_id_attribute.to_s.strip.blank?
      raise InvalidCatalog, 'tax id attribute is required for contact_attribute source'
    end

    configuration = {
      'board_key' => normalized_board_key,
      'provider_connection_id' => connection.id,
      'amount_cents' => normalized_amount,
      'billing_type' => normalized_billing_type,
      'currency' => normalized_currency,
      'due_in_days' => normalized_due_days,
      'tax_id_source' => normalized_tax_id_source
    }
    configuration['description'] = description.to_s.strip if description.present?
    configuration['tax_id_attribute'] = tax_id_attribute.to_s.strip if tax_id_attribute.present?

    settings = @integration.settings.deep_dup
    finance = settings['finance'] ||= {}
    charges = finance['charges'] ||= {}
    charges[normalized_key] = configuration
    @integration.update!(settings: settings)

    {
      'charge_key' => normalized_key,
      'board_key' => normalized_board_key,
      'provider' => connection.provider,
      'environment' => connection.environment
    }
  end

  private

  def positive_integer(value)
    integer = Integer(value)
    integer.positive? ? integer : nil
  rescue ArgumentError, TypeError
    nil
  end

  def non_negative_integer(value)
    integer = Integer(value)
    integer >= 0 ? integer : nil
  rescue ArgumentError, TypeError
    nil
  end
end
