# «Adicionar ao meu calendário»: um evento .ics com a consulta.
class KanbanCalendar::BookingIcs
  def initialize(appointment:)
    @appointment = appointment
  end

  def to_s
    lines = [
      'BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//Raevo//Agenda//PT', 'CALSCALE:GREGORIAN', 'METHOD:PUBLISH',
      'BEGIN:VEVENT',
      "UID:raevo-appointment-#{@appointment.id}@raevo",
      "DTSTAMP:#{utc(Time.current)}",
      "DTSTART:#{utc(@appointment.starts_at)}",
      "DTEND:#{utc(@appointment.ends_at)}",
      "SUMMARY:#{escape(summary)}",
      ("LOCATION:#{escape(location)}" if location.present?),
      'END:VEVENT', 'END:VCALENDAR'
    ].compact
    "#{lines.join("\r\n")}\r\n"
  end

  private

  def summary
    procedure = @appointment.kanban_calendar_procedure
    clinic = page&.clinic_name.presence || @appointment.account.name
    "#{procedure.public_title.presence || procedure.name} · #{clinic}"
  end

  def location
    [page&.clinic_name, page&.clinic_address].compact_blank.join(', ')
  end

  def page
    @page ||= KanbanCalendarBookingPage.find_by(account_id: @appointment.account_id)
  end

  def utc(time)
    time.utc.strftime('%Y%m%dT%H%M%SZ')
  end

  def escape(text)
    text.to_s.gsub(/[\\,;]/) { |char| "\\#{char}" }.gsub("\n", '\\n')
  end
end
