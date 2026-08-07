class KanbanCalendar::AvailabilityQuery
  def initialize(resource:, starts_at:, ends_at:)
    @resource = resource
    @starts_at = starts_at
    @ends_at = ends_at
  end

  def available?
    return true if rules.empty?
    return false if blocked?

    available_in_window?
  end

  private

  def rules
    @rules ||= @resource.kanban_calendar_availability_rules.active.to_a
  end

  def local_starts_at
    @local_starts_at ||= @starts_at.in_time_zone(@resource.timezone)
  end

  def local_ends_at
    @local_ends_at ||= @ends_at.in_time_zone(@resource.timezone)
  end

  def local_date
    local_starts_at.to_date
  end

  def date_rules
    rules.select { |rule| rule.date == local_date }
  end

  def active_windows
    overrides = date_rules.select(&:date_override?)
    return overrides if overrides.any?

    rules.select { |rule| rule.weekly_window? && rule.weekday == local_date.wday }
  end

  def blocked?
    date_rules.select(&:block?).any? do |rule|
      rule.starts_at_local.blank? || local_window_overlaps?(rule)
    end
  end

  def available_in_window?
    active_windows.any? { |rule| local_window_contains?(rule) }
  end

  def local_window_contains?(rule)
    local_starts_at.seconds_since_midnight >= rule.starts_at_local.seconds_since_midnight &&
      local_ends_at.seconds_since_midnight <= rule.ends_at_local.seconds_since_midnight &&
      local_starts_at.to_date == local_ends_at.to_date
  end

  def local_window_overlaps?(rule)
    local_starts_at.seconds_since_midnight < rule.ends_at_local.seconds_since_midnight &&
      local_ends_at.seconds_since_midnight > rule.starts_at_local.seconds_since_midnight
  end
end
