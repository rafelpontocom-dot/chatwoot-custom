class KanbanCalendar::GoogleCalendarTokenService
  GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token'.freeze

  def initialize(connection:)
    @connection = connection
  end

  def access_token
    return @connection.access_token unless @connection.token_expired?

    refresh_access_token
  end

  private

  def refresh_access_token
    response = Faraday.post(
      GOOGLE_TOKEN_URL,
      {
        client_id: GlobalConfigService.load('GOOGLE_CALENDAR_OAUTH_CLIENT_ID', nil),
        client_secret: GlobalConfigService.load('GOOGLE_CALENDAR_OAUTH_CLIENT_SECRET', nil),
        grant_type: 'refresh_token',
        refresh_token: @connection.refresh_token
      }
    )
    payload = JSON.parse(response.body)
    raise KanbanCalendar::GoogleCalendarApiError, payload['error_description'] || 'Google token refresh failed' unless response.success?

    @connection.update!(
      access_token: payload.fetch('access_token'),
      refresh_token: payload['refresh_token'].presence || @connection.refresh_token,
      expires_at: Time.current + payload.fetch('expires_in').to_i.seconds,
      status: 'connected',
      last_error: nil
    )
    @connection.access_token
  end
end
