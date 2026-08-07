class KanbanCalendar::AppointmentEventDispatcher
  EVENT_NAMES = {
    'created' => Events::Types::KANBAN_APPOINTMENT_CREATED,
    'rescheduled' => Events::Types::KANBAN_APPOINTMENT_RESCHEDULED,
    'canceled' => Events::Types::KANBAN_APPOINTMENT_CANCELED,
    'confirmed' => Events::Types::KANBAN_APPOINTMENT_CONFIRMED,
    'completed' => Events::Types::KANBAN_APPOINTMENT_COMPLETED,
    'no_show' => Events::Types::KANBAN_APPOINTMENT_NO_SHOW
  }.freeze

  def initialize(appointment:, event_type:)
    @appointment = appointment
    @event_type = event_type
  end

  def dispatch
    return unless event_name && @appointment.kanban_card

    Rails.configuration.dispatcher.dispatch(event_name, Time.current, event_data)
  end

  private

  def event_name
    EVENT_NAMES[@event_type]
  end

  def event_data
    {
      account_id: @appointment.account_id,
      board_id: @appointment.kanban_card.kanban_board_id,
      card_id: @appointment.kanban_card_id,
      appointment_id: @appointment.id,
      appointment_version: @appointment.appointment_version,
      appointment_status: @appointment.status,
      appointment_starts_at: @appointment.starts_at.iso8601,
      appointment_ends_at: @appointment.ends_at.iso8601,
      event_key: "appointment:#{@appointment.id}:#{@event_type}:v#{@appointment.appointment_version}"
    }
  end
end
