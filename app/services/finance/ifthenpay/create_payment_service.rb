# Creates an ifthenpay charge for one of the Portuguese payment methods.
#
# Unlike Asaas, ifthenpay has no customer object: every method is a one-shot
# request that returns either a reference the customer pays later (Multibanco,
# Payshop), a push notification to their phone (MB WAY) or a hosted page
# (credit card). Settlement always arrives through the callback.
class Finance::Ifthenpay::CreatePaymentService
  SUPPORTED_BILLING_TYPES = %w[multibanco mbway payshop credit_card].freeze
  DEFAULT_EXPIRY_DAYS = 3
  # ifthenpay caps orderId at 25 characters, so the UUID default will not do.
  ORDER_ID_PREFIX = 'itp'.freeze

  def initialize(connection:, contact:, **attributes)
    @connection = connection
    @contact = contact
    @amount_cents = attributes.fetch(:amount_cents)
    @billing_type = attributes.fetch(:billing_type).to_s
    @due_on = attributes[:due_on]
    @description = attributes[:description]
    @kanban_card = attributes[:kanban_card]
    @actor = attributes[:actor]
    @mobile_number = attributes[:mobile_number]
    @external_reference = attributes[:external_reference].presence || generate_order_id
    @currency = attributes.fetch(:currency, 'EUR')
  end

  def perform
    ensure_connection_ready!
    ensure_billing_type_supported!
    payment = create_payment_record
    response = request_charge(payment)
    persist_provider_payment(payment, response)
    Finance::PaymentCreatedEventService.new(payment: payment, source: 'ifthenpay_create', actor: @actor).perform

    payment
  rescue Finance::Ifthenpay::ApiError
    payment.destroy! if payment&.persisted?
    raise
  end

  private

  def ensure_connection_ready!
    return if @connection.provider == 'ifthenpay' && @connection.status == 'connected'

    raise Finance::Ifthenpay::ApiError, 'The ifthenpay connection must be validated before creating charges'
  end

  def ensure_billing_type_supported!
    unless @billing_type.in?(SUPPORTED_BILLING_TYPES)
      raise Finance::Ifthenpay::ApiError, "ifthenpay does not support the #{@billing_type} billing type"
    end
    return if @connection.ifthenpay_method_key(@billing_type).present?

    raise Finance::Ifthenpay::ApiError, "No ifthenpay key configured for #{@billing_type}"
  end

  def create_payment_record
    FinancePayment.create!(
      account: @connection.account,
      contact: @contact,
      kanban_card: @kanban_card,
      finance_provider_connection: @connection,
      amount_cents: @amount_cents,
      currency: @currency,
      billing_type: @billing_type,
      due_on: @due_on,
      description: @description,
      external_reference: @external_reference,
      status: 'pending'
    )
  end

  def request_charge(payment)
    case @billing_type
    when 'multibanco' then multibanco_charge(payment)
    when 'mbway' then mbway_charge(payment)
    when 'payshop' then payshop_charge(payment)
    when 'credit_card' then credit_card_charge(payment)
    end
  end

  def multibanco_charge(payment)
    client.create_multibanco_reference(
      order_id: payment.external_reference,
      amount: formatted_amount,
      description: truncated_description(255),
      expiry_days: expiry_days
    )
  end

  def mbway_charge(payment)
    client.create_mbway_payment(
      order_id: payment.external_reference,
      amount: formatted_amount,
      mobile_number: mbway_mobile_number!,
      email: @contact.email.presence,
      description: truncated_description(100)
    )
  end

  def payshop_charge(payment)
    client.create_payshop_reference(
      order_id: payment.external_reference,
      amount: formatted_amount,
      expires_on: @due_on || expiry_days.days.from_now.to_date
    )
  end

  def credit_card_charge(payment)
    client.create_credit_card_payment(
      order_id: payment.external_reference,
      amount: formatted_amount,
      return_urls: { success: return_url('success'), error: return_url('error'), cancel: return_url('cancel') },
      language: settings['language'].presence || 'pt'
    )
  end

  def persist_provider_payment(payment, response)
    payment.update!(
      provider_payment_id: response['RequestId'].presence,
      invoice_url: response['PaymentUrl'].presence,
      provider_payload: response.merge(reference_summary(response))
    )
  end

  # Entity/reference are what the customer actually needs, so keep them where
  # the dashboard and the WhatsApp follow-up can read them back.
  def reference_summary(response)
    {
      'ifthenpay_method' => @billing_type,
      'ifthenpay_entity' => response['Entity'].presence,
      'ifthenpay_reference' => response['Reference'].presence
    }.compact
  end

  def mbway_mobile_number!
    number = @mobile_number.presence || @contact.phone_number.presence
    normalized = normalize_mobile(number)
    return normalized if normalized.present?

    raise Finance::Ifthenpay::ApiError, 'MB WAY requires a valid Portuguese mobile number'
  end

  # ifthenpay accepts 912345678 or 351#912345678; contacts are stored as +351912345678.
  def normalize_mobile(number)
    digits = number.to_s.gsub(/\D/, '')
    digits = digits.delete_prefix('351') if digits.length > 9 && digits.start_with?('351')
    return unless digits.match?(/\A9[123689]\d{7}\z/)

    "351##{digits}"
  end

  def formatted_amount
    format('%.2f', @amount_cents / 100.0)
  end

  def truncated_description(limit)
    @description.presence&.truncate(limit)
  end

  def expiry_days
    configured = settings['mb_expiry_days'].to_i
    configured.positive? ? configured : DEFAULT_EXPIRY_DAYS
  end

  def return_url(outcome)
    configured = settings["credit_card_#{outcome}_url"].presence
    configured || "#{base_url}/app/accounts/#{@connection.account_id}/finance?payment=#{outcome}"
  end

  def base_url
    ENV.fetch('FRONTEND_URL', 'http://localhost:3000').chomp('/')
  end

  def settings
    @settings ||= @connection.settings.to_h
  end

  def generate_order_id
    "#{ORDER_ID_PREFIX}-#{SecureRandom.alphanumeric(16).downcase}"
  end

  def client
    @client ||= Finance::Ifthenpay::Client.new(connection: @connection)
  end
end
