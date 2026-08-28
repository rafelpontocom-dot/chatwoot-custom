class Finance::Asaas::Client
  SANDBOX_API_URL = 'https://api-sandbox.asaas.com/v3'.freeze
  PRODUCTION_API_URL = 'https://api.asaas.com/v3'.freeze
  REQUEST_TIMEOUT_SECONDS = 15
  NETWORK_ERRORS = [Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED].freeze

  def initialize(connection:)
    @connection = connection
  end

  def create_customer(name:, cpf_cnpj:, external_reference:, email: nil, mobile_phone: nil)
    request(
      :post,
      'customers',
      compact_payload(
        name: name,
        cpfCnpj: cpf_cnpj,
        email: email,
        mobilePhone: mobile_phone,
        externalReference: external_reference
      )
    )
  end

  def account
    request(:get, 'myAccount', nil)
  end

  def create_payment(customer_id:, payload:)
    request(
      :post,
      'payments',
      compact_payload(
        customer: customer_id,
        billingType: payload.fetch(:billing_type),
        value: payload.fetch(:value),
        dueDate: payload.fetch(:due_date).iso8601,
        description: payload[:description],
        externalReference: payload.fetch(:external_reference)
      )
    )
  end

  def find_payment_by_external_reference(external_reference)
    response = request(:get, 'payments', externalReference: external_reference)

    Array(response['data']).first
  end

  def delete_payment(payment_id)
    request(:delete, "payments/#{payment_id}", nil)
  end

  def refund_payment(payment_id, description: nil)
    request(:post, "payments/#{payment_id}/refund", compact_payload(description: description))
  end

  private

  def request(method, path, payload)
    options = { headers: headers, timeout: REQUEST_TIMEOUT_SECONDS }
    if method == :get
      options[:query] = payload if payload.present?
    elsif payload.present?
      options[:body] = payload.to_json
    end
    response = HTTParty.public_send(method, "#{api_url}/#{path}", **options)
    return parsed_body(response) if response.success?

    raise Finance::Asaas::ApiError, error_message(response)
  rescue JSON::ParserError
    raise Finance::Asaas::ApiError, 'Asaas request failed'
  rescue *NETWORK_ERRORS
    raise Finance::Asaas::RequestUncertainError, 'Asaas request could not be confirmed'
  end

  def api_url
    @connection.environment == 'production' ? PRODUCTION_API_URL : SANDBOX_API_URL
  end

  def headers
    {
      'access_token' => @connection.api_key,
      'Content-Type' => 'application/json'
    }
  end

  def compact_payload(payload)
    payload.compact
  end

  def parsed_body(response)
    JSON.parse(response.body)
  end

  def error_message(response)
    parsed_body(response).dig('errors', 0, 'description').presence || 'Asaas request failed'
  end
end
