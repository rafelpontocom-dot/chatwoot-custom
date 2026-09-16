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
    return @conflict if defined?(@conflict)

    @conflict = appointment_conflict? || external_busy_conflict? || slot_hold_conflict?
  end

  def appointment_conflict?
    KanbanCalendarAppointmentResource.where(kanban_calendar_resource: @resource)
                                     .where(appointment_status: KanbanCalendarAppointment::ACTIVE_STATUSES)
                                     .exists?(['starts_at < ? AND ends_at > ?', reservation_ends_at, reservation_starts_at])
  end

  # Compromisso que só existe na agenda Google de quem está ligado a este recurso.
  def external_busy_conflict?
    KanbanCalendarExternalBusyBlock.where(kanban_calendar_resource: @resource)
                                   .overlapping(reservation_starts_at, reservation_ends_at)
                                   .exists?
  end

  # Alguém está a preencher os dados para este horário na página pública.
  def slot_hold_conflict?
    KanbanCalendarSlotHold.active.for_resource(@resource.id).overlapping(reservation_starts_at, reservation_ends_at).exists?
  end

  def resource_allowed?
    !@procedure.kanban_calendar_resources.exists? ||
      @procedure.kanban_calendar_resources.exists?(id: @resource.id)
  end

  def availability_query
    KanbanCalendar::AvailabilityQuery.new(
      resource: @resource,
      procedure: @procedure,
      starts_at: reservation_starts_at,
      ends_at: reservation_ends_at
    )
  end

  def ends_at
    @ends_at ||= @starts_at + @procedure.duration_minutes.minutes
  end

  def reservation_starts_at
    @reservation_starts_at ||= @starts_at - @procedure.buffer_before_minutes.minutes
  end

  def reservation_ends_at
    @reservation_ends_at ||= ends_at + @procedure.buffer_after_minutes.minutes
  end
end
