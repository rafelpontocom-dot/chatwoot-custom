class Finance::Asaas::VerifyConnectionService
  def initialize(connection:)
    @connection = connection
  end

  def perform
    account = Finance::Asaas::Client.new(connection: @connection).account
    @connection.update!(
      status: 'connected',
      provider_account_id: account['id'],
      display_name: @connection.display_name.presence || account['name'],
      last_verified_at: Time.current,
      last_error: nil
    )
    @connection
  rescue Finance::Asaas::ApiError => e
    @connection.update!(status: 'error', last_error: e.message)
    raise
  end
end
