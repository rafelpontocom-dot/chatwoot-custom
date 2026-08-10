class Api::V1::Accounts::Calendar::AppointmentsController < Api::V1::Accounts::BaseController
  before_action :fetch_appointment, only: [:show, :update, :reschedule]
  def index
    authorize KanbanCalendarAppointment, :index?
    return unless index_query_provided?

    render json: index_appointments.map { |appointment| appointment_payload(appointment) }
  end

  def show
    authorize @appointment, :show?
    render json: appointment_payload(@appointment, include_events: true)
  end

  def availability
    authorize KanbanCalendarAppointment, :index?
    return render_available_slots if params[:date].present?

    starts_at = Time.zone.parse(params.require(:starts_at))
    return render_invalid_availability if starts_at.blank?

    render json: KanbanCalendar::AvailabilityCheckService.new(
      procedure: scoped_availability_procedure,
      resource: scoped_availability_resource,
      starts_at: starts_at
    ).call
  end

  def create
    authorize KanbanCalendarAppointment, :create?
    appointment = booking_service.perform!
    render json: appointment_payload(appointment), status: :created
  rescue KanbanCalendar::ConflictError => e
    render json: { message: e.message, resource_ids: e.resource_ids }, status: :conflict
  rescue ActiveRecord::RecordInvalid => e
    render_invalid_record(e.record)
  end

  def update
    authorize @appointment, :update?
    appointment = KanbanCalendar::UpdateAppointmentStatusService.new(
      appointment: @appointment,
      action: update_params[:action],
      cancellation_reason: update_params[:cancellation_reason],
      scope: update_params[:scope],
      expected_lock_version: update_params[:lock_version],
      actor: Current.user
    ).perform!
    render json: appointment_payload(appointment, include_events: true)
  rescue ActiveRecord::RecordInvalid => e
    render_invalid_record(e.record)
  rescue ActiveRecord::StaleObjectError
    render json: { message: 'This appointment changed. Reload it and try again.' }, status: :conflict
  end

  def reschedule
    authorize @appointment, :update?
    appointment = KanbanCalendar::RescheduleAppointmentService.new(
      appointment: @appointment,
      starts_at: Time.zone.parse(reschedule_params[:starts_at]),
      resource_ids: reschedule_params[:resource_ids],
      scope: reschedule_params[:scope],
      expected_lock_version: reschedule_params[:lock_version],
      actor: Current.user
    ).perform!
    render json: appointment_payload(appointment, include_events: true)
  rescue KanbanCalendar::ConflictError => e
    render json: { message: e.message, resource_ids: e.resource_ids }, status: :conflict
  rescue ActiveRecord::StaleObjectError
    render json: { message: 'This appointment changed. Reload it and try again.' }, status: :conflict
  rescue ActiveRecord::RecordInvalid => e
    render_invalid_record(e.record)
  end

  private

  def fetch_appointment
    @appointment = policy_scope(KanbanCalendarAppointment).find(params[:id])
  end

  def appointment_params
    params.require(:appointment).permit(
      :contact_id,
      :kanban_card_id,
      :procedure_id,
      :starts_at,
      :timezone,
      :occurrence_count,
      :interval_kind,
      :interval_days,
      resource_ids: []
    )
  end

  def update_params
    params.require(:appointment).permit(:action, :cancellation_reason, :scope, :lock_version)
  end

  def reschedule_params
    params.require(:appointment).permit(:starts_at, :scope, :lock_version, resource_ids: [])
  end

  def scoped_contact
    Current.account.contacts.find(appointment_params[:contact_id])
  end

  def scoped_procedure
    policy_scope(KanbanCalendarProcedure).active.find(appointment_params[:procedure_id])
  end

  def scoped_kanban_card
    return if appointment_params[:kanban_card_id].blank?

    policy_scope(KanbanCard).find(appointment_params[:kanban_card_id])
  end

  def booking_service
    KanbanCalendar::BookAppointmentService.new(**booking_attributes)
  end

  def booking_attributes
    {
      account: Current.account,
      contact: scoped_contact,
      procedure: scoped_procedure,
      resource_ids: appointment_params[:resource_ids],
      starts_at: Time.zone.parse(appointment_params[:starts_at]),
      timezone: appointment_params[:timezone],
      occurrence_count: appointment_params[:occurrence_count],
      interval_kind: appointment_params[:interval_kind],
      interval_days: appointment_params[:interval_days],
      kanban_card: scoped_kanban_card,
      actor: Current.user
    }
  end

  def range_start = Time.zone.parse(params[:starts_at])

  def range_end = Time.zone.parse(params[:ends_at])

  def date_range_provided?
    params[:starts_at].present? && params[:ends_at].present?
  end

  def index_query_provided?
    return true if date_range_provided? || params[:kanban_card_id].present? || params[:contact_id].present?

    render json: { message: 'A date range or opportunity is required' }, status: :unprocessable_entity
    false
  end

  def scoped_index_kanban_card
    return if params[:kanban_card_id].blank?

    @scoped_index_kanban_card ||= policy_scope(KanbanCard).find(params[:kanban_card_id])
  end

  def scoped_index_contact
    return if params[:contact_id].blank?

    @scoped_index_contact ||= Current.account.contacts.find(params[:contact_id])
  end

  def appointment_scope
    policy_scope(KanbanCalendarAppointment)
      .includes(:contact, :kanban_calendar_appointment_series, :kanban_calendar_procedure, :kanban_calendar_resources)
      .order(:starts_at)
  end

  def index_appointments
    KanbanCalendar::AppointmentsIndexQuery.new(
      scope: appointment_scope,
      kanban_card: scoped_index_kanban_card,
      contact: scoped_index_contact,
      filters: params.slice(:starts_at, :ends_at, :status, :resource_ids, :q)
    ).call
  end

  def appointment_payload(appointment, include_events: false)
    KanbanCalendar::AppointmentPayloadBuilder.new(appointment, include_events: include_events).call
  end

  def scoped_availability_procedure
    policy_scope(KanbanCalendarProcedure).active.find(params.require(:procedure_id))
  end

  def scoped_availability_resource
    policy_scope(KanbanCalendarResource).active.find(params.require(:resource_id))
  end

  def render_invalid_record(record)
    render json: { message: record.errors.full_messages.to_sentence, errors: record.errors }, status: :unprocessable_entity
  end

  def render_invalid_availability
    render json: { message: 'A valid start time is required' }, status: :unprocessable_entity
  end

  def render_available_slots
    date = Date.iso8601(params[:date])
    slots = KanbanCalendar::AvailabilitySlotsQuery.new(
      procedure: scoped_availability_procedure,
      resource: scoped_availability_resource,
      date: date
    ).call
    render json: { date: date.iso8601, slots: slots.map(&:iso8601) }
  rescue Date::Error
    render json: { message: 'A valid date is required' }, status: :unprocessable_entity
  end
end
