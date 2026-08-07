class KanbanCalendar::RescheduleAppointmentService
  SCOPES = %w[this_occurrence this_and_future all_occurrences].freeze

  def initialize(appointment:, starts_at:, resource_ids:, scope: 'this_occurrence', actor: nil)
    @appointment = appointment
    @starts_at = starts_at
    @resource_ids = Array(resource_ids).map(&:to_i).uniq
    @scope = scope.presence || 'this_occurrence'
    @actor = actor
  end

  def perform!
    validate_references!

    ActiveRecord::Base.transaction do
      @appointment.lock!
      @scope == 'this_occurrence' ? reschedule_single_appointment! : replace_future_series!
    end
  rescue ActiveRecord::StatementInvalid => e
    raise unless e.cause.is_a?(PG::ExclusionViolation)

    raise KanbanCalendar::ConflictError, @resource_ids
  end

  private

  def validate_references!
    validate_reschedulable_appointment!
    validate_scope!
    validate_resources!
    validate_procedure_resources!
  end

  def validate_reschedulable_appointment!
    invalid_appointment!('cannot be rescheduled after it is finalized') unless @appointment.active_for_conflict?
    invalid_appointment!('must have a future start time') if @starts_at.blank?
  end

  def validate_scope!
    invalid_appointment!('uses an unsupported scope') unless @scope.in?(SCOPES)
  end

  def validate_resources!
    return unless @resource_ids.empty? || resources.length != @resource_ids.length

    invalid_appointment!('must include an active resource')
  end

  def validate_procedure_resources!
    return unless restricted_procedure_resources? && (resources - procedure.kanban_calendar_resources).any?

    invalid_appointment!('uses a resource not allowed for this procedure')
  end

  def invalid_appointment!(message)
    @appointment.errors.add(:base, message)
    raise ActiveRecord::RecordInvalid, @appointment
  end

  def procedure
    @appointment.kanban_calendar_procedure
  end

  def resources
    @resources ||= @appointment.account.kanban_calendar_resources.active.where(id: @resource_ids).to_a
  end

  def restricted_procedure_resources?
    procedure.kanban_calendar_resources.exists?
  end

  def ends_at
    @ends_at ||= @starts_at + procedure.duration_minutes.minutes
  end

  def reschedule_single_appointment!
    raise KanbanCalendar::ConflictError, conflicting_resource_ids if conflicting_resource_ids.any?

    previous_values = appointment_time_values
    @appointment.update!(
      starts_at: @starts_at,
      ends_at: ends_at,
      appointment_version: @appointment.appointment_version + 1
    )
    replace_resource_reservations!
    create_rescheduled_event!(@appointment, previous_values)
    @appointment
  end

  def replace_future_series!
    appointments = scoped_active_appointments.lock.to_a
    invalid_appointment!('does not have active appointments in this scope') if appointments.empty?

    cancel_replaced_appointments!(appointments)
    replacement = create_replacement_series!(appointments.length)
    mark_original_series_complete_if_needed!
    replacement
  end

  def scoped_active_appointments
    appointments = @appointment.kanban_calendar_appointment_series.kanban_calendar_appointments.active
    return appointments if @scope == 'all_occurrences'

    appointments.where('occurrence_number >= ?', @appointment.occurrence_number)
  end

  def cancel_replaced_appointments!(appointments)
    appointments.each do |appointment|
      appointment.update!(
        status: 'canceled',
        canceled_at: Time.current,
        canceled_by: @actor,
        cancellation_reason: 'Rescheduled into a derived series'
      )
      update_resource_reservations!(appointment, 'canceled')
      create_rescheduled_event!(appointment, appointment_time_values(appointment).merge('scope' => @scope))
    end
  end

  def create_replacement_series!(occurrence_count)
    KanbanCalendar::BookAppointmentService.new(
      account: @appointment.account,
      contact: @appointment.contact,
      procedure: procedure,
      resource_ids: @resource_ids,
      starts_at: @starts_at,
      timezone: @appointment.timezone,
      occurrence_count: occurrence_count,
      interval_kind: replacement_interval_kind(occurrence_count),
      interval_days: @appointment.kanban_calendar_appointment_series.interval_days,
      kanban_card: @appointment.kanban_card,
      actor: @actor
    ).perform!
  end

  def replacement_interval_kind(occurrence_count)
    return 'once' if occurrence_count == 1

    @appointment.kanban_calendar_appointment_series.interval_kind
  end

  def mark_original_series_complete_if_needed!
    series = @appointment.kanban_calendar_appointment_series
    return if series.kanban_calendar_appointments.active.exists?

    series.update!(status: 'canceled', ended_at: Time.current)
  end

  def conflicting_resource_ids
    KanbanCalendarAppointmentResource.where(kanban_calendar_resource_id: @resource_ids)
                                     .where(appointment_status: KanbanCalendarAppointment::ACTIVE_STATUSES)
                                     .where.not(kanban_calendar_appointment_id: @appointment.id)
                                     .where('starts_at < ? AND ends_at > ?', ends_at, @starts_at)
                                     .distinct
                                     .pluck(:kanban_calendar_resource_id)
  end

  def appointment_time_values(appointment = @appointment)
    {
      'previous_starts_at' => appointment.starts_at.iso8601,
      'previous_ends_at' => appointment.ends_at.iso8601,
      'previous_version' => appointment.appointment_version
    }
  end

  def replace_resource_reservations!
    KanbanCalendarAppointmentResource.where(kanban_calendar_appointment: @appointment).delete_all
    resources.each do |resource|
      @appointment.kanban_calendar_appointment_resources.create!(
        kanban_calendar_resource: resource,
        starts_at: @appointment.starts_at,
        ends_at: @appointment.ends_at,
        appointment_status: @appointment.status
      )
    end
  end

  def update_resource_reservations!(appointment, status)
    appointment.kanban_calendar_appointment_resources.find_each do |reservation|
      reservation.update!(appointment_status: status)
    end
  end

  def create_rescheduled_event!(appointment, metadata)
    appointment.kanban_calendar_appointment_events.create!(
      account: appointment.account,
      actor: @actor,
      event_type: 'rescheduled',
      occurred_at: Time.current,
      metadata: metadata
    )
  end
end
