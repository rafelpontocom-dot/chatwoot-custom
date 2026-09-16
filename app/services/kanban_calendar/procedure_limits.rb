# O limite que vale para um procedimento, num sítio só.
#
# Precedência: procedimento → agenda (só o espaçamento) → página de agendamento
# da conta → omissão do código. Antecedência, janela futura e máximo por dia
# protegem a agenda de quem marca sozinho pela página pública; a secretária, a
# marcar por dentro, continua livre para encaixar amanhã cedo.
class KanbanCalendar::ProcedureLimits
  DEFAULT_SLOT_INTERVAL_MINUTES = 15
  DEFAULT_MINIMUM_NOTICE_MINUTES = 0
  DEFAULT_MAXIMUM_NOTICE_DAYS = 60

  def initialize(procedure:, resource: nil)
    @procedure = procedure
    @resource = resource
  end

  def slot_interval_minutes
    @procedure.slot_interval_minutes || @resource&.slot_interval_minutes || booking_page&.slot_interval_minutes ||
      DEFAULT_SLOT_INTERVAL_MINUTES
  end

  def minimum_notice_minutes
    @procedure.minimum_notice_minutes || booking_page&.minimum_notice_minutes || DEFAULT_MINIMUM_NOTICE_MINUTES
  end

  def maximum_notice_days
    @procedure.maximum_notice_days || booking_page&.maximum_notice_days || DEFAULT_MAXIMUM_NOTICE_DAYS
  end

  def daily_limit
    @procedure.daily_limit
  end

  def bookable_by_patient?(starts_at, now: Time.current)
    starts_at.between?(now + minimum_notice_minutes.minutes, now + maximum_notice_days.days)
  end

  def daily_limit_reached?(date, timezone)
    return false if daily_limit.blank?

    day = ActiveSupport::TimeZone[timezone].local(date.year, date.month, date.day)
    @procedure.kanban_calendar_appointments.active.where(starts_at: day.all_day).count >= daily_limit
  end

  private

  def booking_page
    return @booking_page if defined?(@booking_page)

    @booking_page = KanbanCalendarBookingPage.find_by(account_id: @procedure.account_id)
  end
end
