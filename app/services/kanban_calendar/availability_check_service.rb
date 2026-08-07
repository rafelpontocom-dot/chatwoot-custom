class KanbanCalendar::AvailabilityCheckService
  def initialize(procedure:, resource:, starts_at:)
    @procedure = procedure
    @resource = resource
    @starts_at = starts_at
  end

  def call
    {
      available: available?,
      conflict: conflict?,
      resource_allowed: resource_allowed?,
      starts_at: @starts_at.iso8601,
      ends_at: ends_at.iso8601
    }
  end

  private

  def available?
    resource_allowed? && !conflict? && availability_query.available?
  end

  def conflict?
    @conflict ||= KanbanCalendarAppointmentResource.where(kanban_calendar_resource: @resource)
                                                   .where(appointment_status: KanbanCalendarAppointment::ACTIVE_STATUSES)
                                                   .exists?(['starts_at < ? AND ends_at > ?', ends_at, @starts_at])
  end

  def resource_allowed?
    !@procedure.kanban_calendar_resources.exists? ||
      @procedure.kanban_calendar_resources.exists?(id: @resource.id)
  end

  def availability_query
    KanbanCalendar::AvailabilityQuery.new(
      resource: @resource,
      starts_at: @starts_at,
      ends_at: ends_at
    )
  end

  def ends_at
    @ends_at ||= @starts_at + @procedure.duration_minutes.minutes
  end
end
