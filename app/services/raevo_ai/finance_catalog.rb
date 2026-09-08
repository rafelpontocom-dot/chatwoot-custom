class RaevoAi::FinanceCatalog
  class InvalidCatalog < StandardError; end

  def initialize(integration:)
    @integration = integration
  end

  def resolve_charge!(charge_key:, board_key:)
    validate_finance_module!
    configuration = charges.fetch(charge_key.to_s, nil)
    validate_charge_configuration!(configuration, board_key)
    connection = resolved_connection(configuration)
    terms = resolved_terms(configuration)

    {
      key: charge_key.to_s,
      connection: connection,
      **terms,
      description: configuration['description'].presence,
      tax_id_source: configuration['tax_id_source'].presence || 'contact_attribute',
      tax_id_attribute: configuration['tax_id_attribute'].presence
    }
  end

  private

  def charges
    @integration.settings.fetch('finance', {}).fetch('charges', {})
  end

  def validate_finance_module!
    setting = FinanceModuleSetting.find_by(account: @integration.account)
    raise InvalidCatalog, 'finance module is not enabled for this tenant' unless setting&.enabled?
  end

  def validate_charge_configuration!(configuration, board_key)
    raise InvalidCatalog, 'charge is not published in the tenant catalog' if configuration.blank?
    raise InvalidCatalog, 'charge is not authorized for the requested board' unless configuration['board_key'].to_s == board_key.to_s
    return if configuration['tax_id_source'].blank? || configuration['tax_id_source'].in?(%w[contact_attribute command])

    raise InvalidCatalog, 'configured tax id source is invalid'
  end

  def resolved_connection(configuration)
    connection = @integration.account.finance_provider_connections.find_by(id: positive_integer(configuration['provider_connection_id']))
    raise InvalidCatalog, 'configured finance connection is invalid' if connection.blank? || connection.status != 'connected'

    connection
  end

  def resolved_terms(configuration)
    amount_cents = positive_integer(configuration['amount_cents'])
    billing_type = configuration['billing_type'].to_s
    currency = configuration['currency'].to_s.upcase
    due_in_days = non_negative_integer(configuration['due_in_days'])
    raise InvalidCatalog, 'configured charge amount is invalid' if amount_cents.blank?
    raise InvalidCatalog, 'configured billing type is invalid' unless billing_type.in?(FinancePayment::BILLING_TYPES)
    raise InvalidCatalog, 'configured charge currency is invalid' unless currency.match?(/\A[A-Z]{3}\z/)
    raise InvalidCatalog, 'configured charge due date policy is invalid' if due_in_days.blank?

    { amount_cents: amount_cents, billing_type: billing_type, currency: currency, due_on: Date.current + due_in_days.days }
  end

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
