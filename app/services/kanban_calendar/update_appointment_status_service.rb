class KanbanCalendar::UpdateAppointmentStatusService
  ACTIONS = %w[confirm check_in complete no_show cancel].freeze
  CANCELLATION_SCOPES = %w[this_occurrence this_and_future all_occurrences].freeze

  def initialize(appointment:, action:, actor: nil, cancellation_reason: nil, scope: 'this_occurrence')
    @appointment = appointment
    @action = action
    @actor = actor
    @cancellation_reason = cancellation_reason.to_s.strip
    @scope = scope.presence || 'this_occurrence'
  end

  def perform!
    validate_action!

    appointments = ActiveRecord::Base.transaction do
      @appointment.lock!
      appointments = appointments_to_update
      appointments.each do |appointment|
        update_appointment!(appointment)
      end
      update_series_status!
      appointments
    end
    appointments.each { |appointment| dispatch_appointment_event(appointment) }
    mirror_legacy_next_appointment
    @appointment.reload
  end

  private

  def validate_action!
    invalid_action!('is not supported') unless @action.in?(ACTIONS)
    invalid_action!('requires a reason') if @action == 'cancel' && @cancellation_reason.blank?
    invalid_action!('uses an unsupported cancellation scope') if @action == 'cancel' && !@scope.in?(CANCELLATION_SCOPES)
    invalid_action!('cannot be changed after it is finalized') unless @appointment.active_for_conflict?
  end

  def invalid_action!(message)
    @appointment.errors.add(:status, "#{@action} #{message}")
    raise ActiveRecord::RecordInvalid, @appointment
  end

  def appointment_attributes
    case @action
    when 'confirm'
      { status: 'confirmed' }
    when 'check_in'
      { status: 'checked_in' }
    when 'complete'
      { status: 'completed', completed_at: Time.current }
    when 'no_show'
      { status: 'no_show', no_show_at: Time.current }
    when 'cancel'
      {
        status: 'canceled',
        canceled_at: Time.current,
        canceled_by: @actor,
        cancellation_reason: @cancellation_reason
      }
    end
  end

  def appointments_to_update
    return [@appointment] unless @action == 'cancel'

    active_appointments_for_scope.lock.to_a
  end

  def active_appointments_for_scope
    appointments = @appointment.kanban_calendar_appointment_series.kanban_calendar_appointments.active
    return appointments.where(id: @appointment.id) if @scope == 'this_occurrence'
    return appointments.where('occurrence_number >= ?', @appointment.occurrence_number) if @scope == 'this_and_future'

    appointments
  end

  def update_appointment!(appointment)
    appointment.update!(appointment_attributes)
    appointment.kanban_calendar_appointment_resources.find_each do |reservation|
      reservation.update!(appointment_status: appointment.status)
    end
    create_event!(appointment)
  end

  def update_series_status!
    return unless @action == 'cancel'
    return if @appointment.kanban_calendar_appointment_series.kanban_calendar_appointments.active.exists?

    @appointment.kanban_calendar_appointment_series.update!(status: 'canceled', ended_at: Time.current)
  end

  def create_event!(appointment)
    appointment.kanban_calendar_appointment_events.create!(
      account: appointment.account,
      actor: @actor,
      event_type: event_type,
      occurred_at: Time.current,
      metadata: @action == 'cancel' ? { 'scope' => @scope } : {}
    )
  end

  def dispatch_appointment_event(appointment)
    KanbanCalendar::AppointmentEventDispatcher.new(appointment: appointment, event_type: event_type).dispatch
  end

  def mirror_legacy_next_appointment
    KanbanCalendar::LegacyNextAppointmentMirrorService.new(card: @appointment.kanban_card).perform! if @appointment.kanban_card
  end

  def event_type
    {
      'confirm' => 'confirmed',
      'check_in' => 'checked_in',
      'complete' => 'completed',
      'no_show' => 'no_show',
      'cancel' => 'canceled'
    }.fetch(@action)
  end
end
