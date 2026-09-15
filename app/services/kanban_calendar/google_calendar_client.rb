class KanbanCalendar::GoogleCalendarClient
  API_URL = 'https://www.googleapis.com/calendar/v3'.freeze

  def initialize(connection:)
    @connection = connection
  end

  def create_event(appointment)
    response = request(:post, events_path, event_payload(appointment))
    JSON.parse(response.body).fetch('id')
  end

  def update_event(event_id, appointment)
    request(:put, "#{events_path}/#{CGI.escape(event_id)}", event_payload(appointment))
  end

  def cancel_event(event_id)
    request(:patch, "#{events_path}/#{CGI.escape(event_id)}", { status: 'cancelled' })
  end

  # Eventos da janela já expandidos (`singleEvents`): uma série semanal vem como
  # uma ocorrência por semana, cada uma com o seu id, que é o que a agenda precisa.
  def list_events(time_min:, time_max:)
    items = []
    time_zone = nil
    page_token = nil

    loop do
      body = JSON.parse(request(:get, events_path, nil, params: list_params(time_min, time_max, page_token)).body)
      items.concat(body.fetch('items', []))
      time_zone ||= body['timeZone']
      page_token = body['nextPageToken']
      break if page_token.blank?
    end

    { items: items, time_zone: time_zone }
  end

  private

  def events_path
    "calendars/#{CGI.escape(@connection.calendar_id)}/events"
  end

  def list_params(time_min, time_max, page_token)
    { singleEvents: true, timeMin: time_min.iso8601, timeMax: time_max.iso8601, maxResults: 2500, pageToken: page_token }.compact
  end

  def request(method, path, payload, params: {})
    response = Faraday.public_send(method, "#{API_URL}/#{path}") do |request|
      request.params.update(params)
      request.headers['Authorization'] = "Bearer #{access_token}"
      request.headers['Content-Type'] = 'application/json'
      request.body = payload.to_json if payload
    end
    return response if response.success?

    message = JSON.parse(response.body).dig('error', 'message')
    raise KanbanCalendar::GoogleCalendarApiError, message.presence || 'Google Calendar request failed'
  rescue JSON::ParserError
    raise KanbanCalendar::GoogleCalendarApiError, 'Google Calendar request failed'
  end

  def access_token
    KanbanCalendar::GoogleCalendarTokenService.new(connection: @connection).access_token
  end

  def event_payload(appointment)
    {
      summary: "#{appointment.kanban_calendar_procedure.name} - #{appointment.contact.name}",
      description: "Agendamento gerenciado pelo RAEVO CRM (##{appointment.id})",
      start: { dateTime: appointment.starts_at.iso8601, timeZone: appointment.timezone },
      end: { dateTime: appointment.ends_at.iso8601, timeZone: appointment.timezone },
      extendedProperties: { private: { raevo_appointment_id: appointment.id.to_s, raevo_version: appointment.appointment_version.to_s } }
    }
  end
end
