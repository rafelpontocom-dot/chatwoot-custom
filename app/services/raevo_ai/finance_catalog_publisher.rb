class RaevoAi::FinanceCatalogPublisher
  class InvalidCatalog < StandardError; end

  def initialize(integration:)
    @integration = integration
  end

  def publish!(**input)
    ensure_inactive!
    normalized_key = normalize_charge_key!(input[:charge_key])
    normalized_board_key = normalize_board_key!(input[:board_key])
    ensure_finance_enabled!
    connection = find_connection!(input[:provider_connection_id])
    configuration = build_configuration!(input, normalized_board_key, connection)
    persist_catalog!(normalized_key, configuration)

    {
      'charge_key' => normalized_key,
      'board_key' => normalized_board_key,
      'provider' => connection.provider,
      'environment' => connection.environment
    }
  end

  private

  def ensure_inactive!
    raise InvalidCatalog, 'integration must be inactive while publishing the finance catalog' if @integration.enabled?
  end

  def normalize_charge_key!(charge_key)
    normalized = charge_key.to_s.strip
    raise InvalidCatalog, 'charge_key is invalid' unless normalized.match?(/\A[a-z][a-z0-9_]*\z/)

    normalized
  end

  def normalize_board_key!(board_key)
    normalized = board_key.to_s.strip
    return normalized if @integration.settings.dig('crm', 'boards', normalized, 'board_id').to_i.positive?

    raise InvalidCatalog, 'board is not published in the CRM catalog'
  end

  def ensure_finance_enabled!
    setting = FinanceModuleSetting.find_by(account: @integration.account)
    raise InvalidCatalog, 'finance module is not enabled for this tenant' unless setting&.enabled?
  end

  def find_connection!(provider_connection_id)
    connection = @integration.account.finance_provider_connections.find_by(id: positive_integer(provider_connection_id))
    raise InvalidCatalog, 'finance connection is not connected' if connection.blank? || connection.status != 'connected'

    connection
  end

  def build_configuration!(input, board_key, connection)
    configuration = normalize_charge_configuration!(input).merge(
      'board_key' => board_key,
      'provider_connection_id' => connection.id
    )
    configuration['description'] = input[:description].to_s.strip if input[:description].present?
    configuration['tax_id_attribute'] = input[:tax_id_attribute].to_s.strip if input[:tax_id_attribute].present?
    configuration
  end

  def normalize_charge_configuration!(input)
    configuration = {
      'amount_cents' => positive_integer(input[:amount_cents]),
      'billing_type' => input[:billing_type].to_s,
      'currency' => input[:currency].to_s.upcase,
      'due_in_days' => non_negative_integer(input[:due_in_days]),
      'tax_id_source' => input[:tax_id_source].to_s
    }
    validate_charge_configuration!(configuration, input[:tax_id_attribute])
    configuration
  end

  def validate_charge_configuration!(configuration, tax_id_attribute)
    validate_amount!(configuration['amount_cents'])
    validate_billing_type!(configuration['billing_type'])
    validate_currency!(configuration['currency'])
    validate_due_date!(configuration['due_in_days'])
    validate_tax_id_source!(configuration['tax_id_source'], tax_id_attribute)
  end

  def validate_amount!(amount)
    raise InvalidCatalog, 'amount is invalid' if amount.blank?
  end

  def validate_billing_type!(billing_type)
    raise InvalidCatalog, 'billing type is invalid' unless billing_type.in?(FinancePayment::BILLING_TYPES)
  end

  def validate_currency!(currency)
    raise InvalidCatalog, 'currency is invalid' unless currency.match?(/\A[A-Z]{3}\z/)
  end

  def validate_due_date!(due_in_days)
    raise InvalidCatalog, 'due date policy is invalid' if due_in_days.blank?
  end

  def validate_tax_id_source!(tax_id_source, tax_id_attribute)
    raise InvalidCatalog, 'tax id source is invalid' unless tax_id_source.in?(%w[contact_attribute command])
    return unless tax_id_source == 'contact_attribute' && tax_id_attribute.to_s.strip.blank?

    raise InvalidCatalog, 'tax id attribute is required for contact_attribute source'
  end

  def persist_catalog!(charge_key, configuration)
    settings = @integration.settings.deep_dup
    charges = (settings['finance'] ||= {})['charges'] ||= {}
    charges[charge_key] = configuration
    @integration.update!(settings: settings)
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
