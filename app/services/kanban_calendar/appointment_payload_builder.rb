class KanbanCalendar::AppointmentPayloadBuilder
  def initialize(appointment, include_events: false)
    @appointment = appointment
    @include_events = include_events
  end

  def call
    payload = summary_payload
    payload[:events] = events_payload if @include_events
    payload
  end

  private

  def summary_payload
    {
      id: @appointment.id,
      series_id: @appointment.kanban_calendar_appointment_series_id,
      series: series_payload,
      contact: { id: @appointment.contact_id, name: @appointment.contact.name },
      kanban_card_id: @appointment.kanban_card_id,
      kanban_card: kanban_card_payload,
      procedure: procedure_payload,
      resources: resources_payload,
      status: @appointment.status,
      starts_at: @appointment.starts_at.iso8601,
      ends_at: @appointment.ends_at.iso8601,
      timezone: @appointment.timezone,
      occurrence_number: @appointment.occurrence_number,
      appointment_version: @appointment.appointment_version,
      lock_version: @appointment.lock_version
    }
  end

  def series_payload
    series = @appointment.kanban_calendar_appointment_series
    { planned_count: series.planned_count, interval_kind: series.interval_kind, status: series.status }
  end

  def procedure_payload
    procedure = @appointment.kanban_calendar_procedure
    { id: procedure.id, name: procedure.name, color: procedure.color }
  end

  def resources_payload
    @appointment.kanban_calendar_resources.map { |resource| { id: resource.id, name: resource.name } }
  end

  def kanban_card_payload
    card = @appointment.kanban_card
    return unless card

    { id: card.id, kanban_board_id: card.kanban_board_id, subject: card.subject }
  end

  def events_payload
    @appointment.kanban_calendar_appointment_events.order(:occurred_at).map do |event|
      { id: event.id, event_type: event.event_type, occurred_at: event.occurred_at.iso8601, actor_id: event.actor_id }
    end
  end
end
