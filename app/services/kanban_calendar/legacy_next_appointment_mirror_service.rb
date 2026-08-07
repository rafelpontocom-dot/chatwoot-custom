class KanbanCalendar::LegacyNextAppointmentMirrorService
  def initialize(card:)
    @card = card
  end

  def perform!
    return if field_key.blank?

    values = @card.custom_field_values.to_h
    next_appointment ? values[field_key] = next_appointment.starts_at.iso8601 : values.delete(field_key)
    @card.update!(custom_field_values: values) if values != @card.custom_field_values.to_h
  end

  private

  def field_key
    @field_key ||= @card.kanban_board.calendar_legacy_next_appointment_field_key
  end

  def next_appointment
    @next_appointment ||= KanbanCalendarAppointment.active.where(kanban_card: @card).order(:starts_at).first
  end
end
