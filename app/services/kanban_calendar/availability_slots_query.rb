class KanbanCalendar::AvailabilitySlotsQuery
  SLOT_INTERVAL_MINUTES = 15

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
    starts_at = local_time(window.starts_at_local)
    last_start = local_time(window.ends_at_local) - @procedure.duration_minutes.minutes
    slots = []
    while starts_at <= last_start
      slots << starts_at if available?(starts_at)
      starts_at += SLOT_INTERVAL_MINUTES.minutes
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
end
