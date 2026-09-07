# ifthenpay has no "my account" endpoint, so the backoffice key is validated by
# asking for the payment list: a wrong key is rejected by the gateway.
class Finance::Ifthenpay::VerifyConnectionService
  def initialize(connection:)
    @connection = connection
  end

  def perform
    ensure_anti_phishing_key!
    ensure_method_keys!
    client.list_payments

    @connection.update!(
      status: 'connected',
      display_name: @connection.display_name.presence || 'ifthenpay',
      last_verified_at: Time.current,
      last_error: nil
    )
    @connection
  rescue Finance::Ifthenpay::ApiError => e
    @connection.update!(status: 'error', last_error: e.message)
    raise
  end

  private

  # Without it the callback cannot be authenticated and payments would never
  # be marked as received, so refuse to report the connection as healthy.
  def ensure_anti_phishing_key!
    return if @connection.webhook_token.present?

    raise Finance::Ifthenpay::ApiError, 'The ifthenpay anti-phishing key is required to receive payment confirmations'
  end

  def ensure_method_keys!
    return if @connection.ifthenpay_enabled_billing_types.any?

    raise Finance::Ifthenpay::ApiError, 'Configure at least one ifthenpay payment method key'
  end

  def client
    @client ||= Finance::Ifthenpay::Client.new(connection: @connection)
  end
end
