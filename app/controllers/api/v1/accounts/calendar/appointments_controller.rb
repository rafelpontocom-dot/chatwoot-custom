class Api::V1::Accounts::Calendar::AppointmentsController < Api::V1::Accounts::BaseController
  before_action :fetch_appointment, only: [:show, :update, :reschedule]
  def index
    authorize KanbanCalendarAppointment, :index?
    return unless index_query_provided?

    appointments = appointment_scope
    appointments = appointments.within(range_start, range_end) if date_range_provided?
    appointments = appointments.where(kanban_card: scoped_index_kanban_card) if scoped_index_kanban_card
    appointments = appointments.merge(appointment_search_scope) if search_query.present?
    if resource_ids.present?
      appointments = appointments.joins(:kanban_calendar_appointment_resources)
                                 .where(kanban_calendar_appointment_resources: { kanban_calendar_resource_id: resource_ids })
    end
    render json: appointments.distinct.map { |appointment| appointment_payload(appointment) }
  end

  def show
    authorize @appointment, :show?
    render json: appointment_payload(@appointment, include_events: true)
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
      actor: Current.user
    ).perform!
    render json: appointment_payload(appointment, include_events: true)
  rescue ActiveRecord::RecordInvalid => e
    render_invalid_record(e.record)
  end

  def reschedule
    authorize @appointment, :update?
    appointment = KanbanCalendar::RescheduleAppointmentService.new(
      appointment: @appointment,
      starts_at: Time.zone.parse(reschedule_params[:starts_at]),
      resource_ids: reschedule_params[:resource_ids],
      scope: reschedule_params[:scope],
      actor: Current.user
    ).perform!
    render json: appointment_payload(appointment, include_events: true)
  rescue KanbanCalendar::ConflictError => e
    render json: { message: e.message, resource_ids: e.resource_ids }, status: :conflict
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
    params.require(:appointment).permit(:action, :cancellation_reason, :scope)
  end

  def reschedule_params
    params.require(:appointment).permit(:starts_at, :scope, resource_ids: [])
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
    return true if date_range_provided? || params[:kanban_card_id].present?

    render json: { message: 'A date range or opportunity is required' }, status: :unprocessable_entity
    false
  end

  def scoped_index_kanban_card
    return if params[:kanban_card_id].blank?

    @scoped_index_kanban_card ||= policy_scope(KanbanCard).find(params[:kanban_card_id])
  end

  def resource_ids
    Array(params[:resource_ids]).filter_map(&:presence).map(&:to_i).uniq
  end

  def search_query
    params[:q].to_s.strip
  end

  def appointment_search_scope
    query = "%#{KanbanCalendarAppointment.sanitize_sql_like(search_query)}%"
    KanbanCalendarAppointment.left_joins(:contact, :kanban_card).where(
      'contacts.name ILIKE :query OR contacts.email ILIKE :query OR contacts.phone_number ILIKE :query OR kanban_cards.subject ILIKE :query',
      query: query
    )
  end

  def appointment_scope
    policy_scope(KanbanCalendarAppointment)
      .includes(:contact, :kanban_calendar_procedure, :kanban_calendar_resources)
      .order(:starts_at)
  end

  def appointment_payload(appointment, include_events: false)
    payload = appointment_summary_payload(appointment)
    return payload unless include_events

    payload.merge(events: appointment_events_payload(appointment))
  end

  def appointment_summary_payload(appointment)
    {
      id: appointment.id,
      series_id: appointment.kanban_calendar_appointment_series_id,
      contact: { id: appointment.contact_id, name: appointment.contact.name },
      kanban_card_id: appointment.kanban_card_id,
      procedure: {
        id: appointment.kanban_calendar_procedure_id,
        name: appointment.kanban_calendar_procedure.name,
        color: appointment.kanban_calendar_procedure.color
      },
      resources: appointment.kanban_calendar_resources.map { |resource| { id: resource.id, name: resource.name } },
      status: appointment.status,
      starts_at: appointment.starts_at.iso8601,
      ends_at: appointment.ends_at.iso8601,
      timezone: appointment.timezone,
      occurrence_number: appointment.occurrence_number,
      appointment_version: appointment.appointment_version,
      lock_version: appointment.lock_version
    }
  end

  def appointment_events_payload(appointment)
    appointment.kanban_calendar_appointment_events.order(:occurred_at).map do |event|
      { id: event.id, event_type: event.event_type, occurred_at: event.occurred_at.iso8601, actor_id: event.actor_id }
    end
  end

  def render_invalid_record(record)
    render json: { message: record.errors.full_messages.to_sentence, errors: record.errors }, status: :unprocessable_entity
  end
end
