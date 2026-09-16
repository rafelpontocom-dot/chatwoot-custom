class KanbanCalendar::AvailabilitySlotsQuery
  # `occupancy`, `working_rules`, `limits` e `allowed_resource_ids` evitam repetir
  # consultas quando se pergunta por muitos dias seguidos (calendário do mês).
  def initialize(resource:, procedure:, date:, **cache)
    @resource = resource
    @procedure = procedure
    @date = date
    @occupancy = cache[:occupancy]
    @working_rules = cache[:working_rules]
    @limits = cache[:limits]
    @allowed_resource_ids = cache[:allowed_resource_ids]
  end

  def call
    return [] unless resource_allowed?

    working_windows.flat_map { |window| slots_for(window) }.uniq.sort
  end

  private

  def resource_allowed?
    allowed = @allowed_resource_ids || @procedure.kanban_calendar_resource_ids
    allowed.empty? || allowed.include?(@resource.id)
  end

  def working_windows
    date_rules = availability_rules.select { |rule| rule.date == @date }
    overrides = date_rules.select(&:date_override?)
    return overrides if overrides.any?

    availability_rules.select { |rule| rule.weekly_window? && rule.weekday == @date.wday }
  end

  def availability_rules
    working_rules.rules
  end

  def working_rules
    @working_rules ||= KanbanCalendar::WorkingRules.new(resource: @resource, procedure: @procedure)
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
      starts_at: starts_at,
      occupancy: @occupancy,
      working_rules: working_rules,
      allowed: true
    ).available?
  end

  def timezone
    @timezone ||= ActiveSupport::TimeZone[working_rules.timezone]
  end

  # De quanto em quanto tempo se oferece um horário: o procedimento decide, depois
  # a agenda, depois o padrão da conta, configurado na página de agendamento.
  def slot_interval_minutes
    @slot_interval_minutes ||= @procedure.slot_interval_minutes || @resource.slot_interval_minutes ||
                               (@limits || KanbanCalendar::ProcedureLimits.new(procedure: @procedure)).slot_interval_minutes
  end
end
