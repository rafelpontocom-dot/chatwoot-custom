# Thin HTTP wrapper around the ifthenpay gateway.
#
# Endpoints and payload keys follow the official ifthenpay SDKs
# (github.com/ifthenpay/ifthenpay-sdk-php and github.com/ifthenpay/js-sdk).
# ifthenpay has no sandbox host: test mode is granted by issuing test keys for
# the same production endpoints, so the URLs do not vary per environment.
class Finance::Ifthenpay::Client
  MULTIBANCO_URL = 'https://api.ifthenpay.com/multibanco/reference/init'.freeze
  MBWAY_URL = 'https://api.ifthenpay.com/spg/payment/mbway'.freeze
  MBWAY_STATUS_URL = 'https://api.ifthenpay.com/spg/payment/mbway/status'.freeze
  PAYSHOP_URL = 'https://ifthenpay.com/api/payshop/reference/'.freeze
  CREDIT_CARD_URL = 'https://api.ifthenpay.com/creditcard/init/'.freeze
  REFUND_URL = 'https://ifthenpay.com/api/endpoint/payments/refund'.freeze
  LIST_PAYMENTS_URL = 'https://api.ifthenpay.com/v2/payments/read'.freeze

  REQUEST_TIMEOUT_SECONDS = 15
  NETWORK_ERRORS = [Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED].freeze

  def initialize(connection:)
    @connection = connection
  end

  # Returns Entity + Reference the customer uses at an ATM or homebanking.
  def create_multibanco_reference(order_id:, amount:, description: nil, expiry_days: nil)
    post(
      MULTIBANCO_URL,
      {
        mbKey: method_key!('multibanco'),
        orderId: order_id,
        amount: amount,
        description: description,
        expiryDays: expiry_days
      },
      success_field: 'Status',
      success_value: '0'
    )
  end

  # Pushes a payment request to the customer's MB WAY app.
  def create_mbway_payment(order_id:, amount:, mobile_number:, description: nil, email: nil)
    post(
      MBWAY_URL,
      {
        mbWayKey: method_key!('mbway'),
        orderId: order_id,
        amount: amount,
        mobileNumber: mobile_number,
        email: email,
        description: description
      },
      success_field: 'Status',
      success_value: '000'
    )
  end

  def mbway_status(request_id)
    get(MBWAY_STATUS_URL, mbWayKey: method_key!('mbway'), requestId: request_id)
  end

  # Payshop uses its own casing and Portuguese field names.
  def create_payshop_reference(order_id:, amount:, expires_on: nil)
    post(
      PAYSHOP_URL,
      {
        payshopkey: method_key!('payshop'),
        id: order_id,
        valor: amount,
        validade: expires_on&.strftime('%Y%m%d')
      },
      success_field: 'Code',
      success_value: '0'
    )
  end

  # Returns a hosted payment page the customer is redirected to.
  # return_urls carries :success, :error and :cancel.
  def create_credit_card_payment(order_id:, amount:, return_urls:, language: 'pt')
    post(
      "#{CREDIT_CARD_URL}#{method_key!('credit_card')}",
      {
        orderId: order_id,
        amount: amount,
        successUrl: return_urls.fetch(:success),
        errorUrl: return_urls.fetch(:error),
        cancelUrl: return_urls.fetch(:cancel),
        language: language
      },
      success_field: 'Status',
      success_value: '0'
    )
  end

  # Only MB WAY and card payments can be refunded through the API.
  def refund(request_id:, amount:)
    response = post(
      REFUND_URL,
      { backofficekey: backoffice_key!, requestId: request_id, amount: amount },
      raise_on_error_field: false
    )
    code = response['Code'].to_s
    return response if code == '1'

    message = response['Message'].presence || 'ifthenpay refund failed'
    raise Finance::Ifthenpay::ApiError, code == '-1' ? 'Insufficient balance at ifthenpay to issue this refund' : message
  end

  # Used to validate the backoffice key: a wrong key is rejected by the gateway.
  def list_payments(order_id: nil)
    post(
      LIST_PAYMENTS_URL,
      { boKey: backoffice_key!, orderId: order_id },
      raise_on_error_field: false
    )
  end

  private

  def backoffice_key!
    @connection.api_key.presence ||
      raise(Finance::Ifthenpay::ApiError, 'The ifthenpay backoffice key is missing')
  end

  def method_key!(billing_type)
    @connection.ifthenpay_method_key(billing_type).presence ||
      raise(Finance::Ifthenpay::ApiError, "No ifthenpay key configured for #{billing_type}")
  end

  def post(url, payload, success_field: nil, success_value: nil, raise_on_error_field: true)
    response = HTTParty.post(
      url,
      headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' },
      body: payload.compact.to_json,
      timeout: REQUEST_TIMEOUT_SECONDS
    )
    body = handle(response)
    verify_success!(body, success_field, success_value) if raise_on_error_field && success_field
    body
  end

  def get(url, query)
    handle(
      HTTParty.get(
        url,
        headers: { 'Accept' => 'application/json' },
        query: query.compact,
        timeout: REQUEST_TIMEOUT_SECONDS
      )
    )
  end

  def handle(response)
    return parsed_body(response) if response.success?

    raise Finance::Ifthenpay::ApiError, error_message(response)
  rescue JSON::ParserError
    raise Finance::Ifthenpay::ApiError, 'ifthenpay returned an unreadable response'
  rescue *NETWORK_ERRORS
    raise Finance::Ifthenpay::RequestUncertainError, 'ifthenpay request could not be confirmed'
  end

  # The gateway answers HTTP 200 even when it rejects the request, signalling
  # the outcome through a status field that differs per payment method.
  def verify_success!(body, field, expected)
    return if body[field].to_s == expected

    raise Finance::Ifthenpay::ApiError, body['Message'].presence || "ifthenpay rejected the request (#{field}=#{body[field]})"
  end

  def parsed_body(response)
    body = response.body.to_s.strip
    return {} if body.empty?

    JSON.parse(body)
  end

  def error_message(response)
    parsed = begin
      parsed_body(response)
    rescue JSON::ParserError
      {}
    end
    parsed['Message'].presence || "ifthenpay request failed with HTTP #{response.code}"
  end
end
