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

  private

  def events_path
    "calendars/#{CGI.escape(@connection.calendar_id)}/events"
  end

  def request(method, path, payload)
    response = Faraday.public_send(method, "#{API_URL}/#{path}") do |request|
      request.headers['Authorization'] = "Bearer #{access_token}"
      request.headers['Content-Type'] = 'application/json'
      request.body = payload.to_json
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
