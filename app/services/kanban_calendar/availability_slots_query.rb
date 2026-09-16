class KanbanCalendar::AvailabilitySlotsQuery
  DEFAULT_SLOT_INTERVAL_MINUTES = 15

  def initialize(resource:, procedure:, date:)
    @resource = resource
    @procedure = procedure
    @date = date
  end

  def call
    return [] unless resource_allowed?

    working_windows.flat_map { |window| slots_for(window) }.uniq.sort
  end

  private

  def resource_allowed?
    !@procedure.kanban_calendar_resources.exists? ||
      @procedure.kanban_calendar_resources.exists?(id: @resource.id)
  end

  def working_windows
    date_rules = availability_rules.select { |rule| rule.date == @date }
    overrides = date_rules.select(&:date_override?)
    return overrides if overrides.any?

    availability_rules.select { |rule| rule.weekly_window? && rule.weekday == @date.wday }
  end

  def availability_rules
    @availability_rules ||= @resource.kanban_calendar_availability_rules.active.to_a
  end

  def slots_for(window)
    starts_at = local_time(window.starts_at_local) + @procedure.buffer_before_minutes.minutes
    last_start = local_time(window.ends_at_local) - @procedure.duration_minutes.minutes - @procedure.buffer_after_minutes.minutes
    slots = []
    while starts_at <= last_start
      slots << starts_at if available?(starts_at)
      starts_at += slot_interval_minutes.minutes
    end
    slots
  end

  def local_time(time)
    timezone.local(@date.year, @date.month, @date.day, time.hour, time.min, time.sec)
  end

  def available?(starts_at)
    KanbanCalendar::AvailabilityCheckService.new(
      procedure: @procedure,
      resource: @resource,
      starts_at: starts_at
    ).call[:available]
  end

  def timezone
    @timezone ||= ActiveSupport::TimeZone[@resource.timezone]
  end

  # De quanto em quanto tempo se oferece um horário: a agenda decide, e quem não
  # decidiu segue o padrão da conta, configurado na página de agendamento.
  def slot_interval_minutes
    @slot_interval_minutes ||= @resource.slot_interval_minutes || account_slot_interval_minutes
  end

  def account_slot_interval_minutes
    KanbanCalendarBookingPage.find_by(account_id: @resource.account_id)&.slot_interval_minutes ||
      DEFAULT_SLOT_INTERVAL_MINUTES
  end
end
