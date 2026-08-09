class KanbanCalendar::GoogleCalendarOauthService
  AUTHORIZE_URL = 'https://accounts.google.com/o/oauth2/auth'.freeze
  TOKEN_URL = 'https://oauth2.googleapis.com/token'.freeze
  SCOPE = 'https://www.googleapis.com/auth/calendar.events'.freeze
  STATE_TTL = 10.minutes

  def initialize(resource:)
    @resource = resource
  end

  def authorization_url
    ensure_google_credentials!
    state = SecureRandom.urlsafe_base64(32)
    Rails.cache.write(state_cache_key(state), { resource_id: @resource.id, account_id: @resource.account_id }, expires_in: STATE_TTL)
    oauth_client.auth_code.authorize_url(
      redirect_uri: callback_url,
      scope: SCOPE,
      response_type: 'code',
      prompt: 'consent',
      access_type: 'offline',
      state: state
    )
  end

  def self.connect!(code:, state:)
    new(resource: resource_from_state!(state)).connect!(code)
  end

  def connect!(code)
    token = oauth_client.auth_code.get_token(code, redirect_uri: callback_url)
    attributes = token.to_hash.with_indifferent_access
    connection = @resource.kanban_calendar_google_connection || @resource.build_kanban_calendar_google_connection(account: @resource.account)
    connection.update!(
      access_token: attributes.fetch(:access_token),
      refresh_token: attributes[:refresh_token].presence || connection.refresh_token,
      expires_at: Time.at(attributes.fetch(:expires_at)).utc,
      status: 'connected',
      last_error: nil
    )
    KanbanCalendar::BackfillGoogleCalendarConnectionJob.perform_later(connection.id)
    connection
  end

  def self.resource_from_state!(state)
    payload = Rails.cache.delete(state_cache_key(state))
    raise KanbanCalendar::GoogleCalendarApiError, 'Google authorization expired' if payload.blank?

    KanbanCalendarResource.where(account_id: payload[:account_id]).find(payload[:resource_id])
  end

  def self.state_cache_key(state)
    "kanban_calendar_google_oauth:#{state}"
  end

  private

  def oauth_client
    @oauth_client ||= OAuth2::Client.new(
      GlobalConfigService.load('GOOGLE_CALENDAR_OAUTH_CLIENT_ID', nil),
      GlobalConfigService.load('GOOGLE_CALENDAR_OAUTH_CLIENT_SECRET', nil),
      site: 'https://oauth2.googleapis.com',
      authorize_url: AUTHORIZE_URL,
      token_url: TOKEN_URL
    )
  end

  def ensure_google_credentials!
    return if GlobalConfigService.load('GOOGLE_CALENDAR_OAUTH_CLIENT_ID', nil).present? &&
              GlobalConfigService.load('GOOGLE_CALENDAR_OAUTH_CLIENT_SECRET', nil).present?

    raise KanbanCalendar::GoogleCalendarApiError, 'Google Calendar OAuth is not configured'
  end

  def callback_url
    GlobalConfigService.load(
      'GOOGLE_CALENDAR_OAUTH_CALLBACK_URL',
      "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3000')}/calendar/google/callback"
    )
  end
end
