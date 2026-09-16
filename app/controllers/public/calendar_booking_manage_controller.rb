# A consulta do paciente, pelo token do link que recebeu: ver, adicionar ao
# calendário, remarcar e cancelar dentro da política do procedimento.
class Public::CalendarBookingManageController < PublicController
  before_action :fetch_appointment
  before_action :enforce_rate_limit, only: [:hold, :reschedule, :cancel]

  def show
    respond_to do |format|
      format.html do
        @booking_page = booking_page
        render 'public/calendar_bookings/show', layout: 'public_calendar_booking'
      end
      format.json { render json: payload }
    end
  end

  def ics
    send_data KanbanCalendar::BookingIcs.new(appointment: @appointment).to_s,
              filename: 'consulta.ics', type: 'text/calendar; charset=utf-8', disposition: 'attachment'
  end

  def availability
    render json: params[:month].present? ? month_payload : day_payload
  rescue ArgumentError, ActionController::ParameterMissing
    render json: { message: 'Invalid booking request' }, status: :unprocessable_entity
  end

  def hold
    return render_not_allowed unless changes.can_reschedule?

    hold = KanbanCalendar::PublicSlotHoldService.new(
      procedure: procedure, starts_at: Time.zone.parse(params.require(:starts_at)),
      timezone: params[:timezone].presence || @appointment.timezone, appointment: @appointment
    ).perform!
    render json: { token: hold.token, starts_at: hold.starts_at.iso8601, expires_at: hold.expires_at.iso8601 }, status: :created
  rescue KanbanCalendar::ConflictError
    render json: { message: 'This time is no longer available', code: 'slot_taken' }, status: :conflict
  rescue ArgumentError, ActionController::ParameterMissing
    render json: { message: 'Invalid booking request' }, status: :unprocessable_entity
  end

  def reschedule
    hold = KanbanCalendarSlotHold.find_by!(token: params.require(:hold_token))
    replacement = changes.reschedule!(hold)
    render json: KanbanCalendar::PatientBookingPayload.new(appointment: replacement).call
  rescue KanbanCalendar::PatientChangeService::NotAllowed, ActiveRecord::RecordNotFound => e
    render json: { message: e.message }, status: :unprocessable_entity
  rescue KanbanCalendar::ConflictError
    render json: { message: 'This time is no longer available', code: 'slot_taken' }, status: :conflict
  end

  def cancel
    changes.cancel!(params[:reason].to_s.strip)
    render json: KanbanCalendar::PatientBookingPayload.new(appointment: @appointment.reload).call
  rescue KanbanCalendar::PatientChangeService::NotAllowed, ActiveRecord::RecordInvalid => e
    render json: { message: e.message }, status: :unprocessable_entity
  end

  private

  def fetch_appointment
    @appointment = KanbanCalendarAppointment.find_by!(hold_token: params[:booking_token])
  rescue ActiveRecord::RecordNotFound
    render json: { message: 'Booking not found' }, status: :not_found
  end

  def procedure
    @appointment.kanban_calendar_procedure
  end

  def changes
    @changes ||= KanbanCalendar::PatientChangeService.new(appointment: @appointment)
  end

  def booking_page
    KanbanCalendarBookingPage.find_by!(account_id: @appointment.account_id)
  end

  def payload
    KanbanCalendar::PatientBookingPayload.new(appointment: @appointment).call
  end

  def patient_availability
    @patient_availability ||= KanbanCalendar::ProcedureAvailability.new(procedure: procedure, patient: true)
  end

  def month_payload
    first = Date.strptime(params[:month], '%Y-%m')
    from = [first, Time.current.in_time_zone(patient_availability.timezone).to_date].max
    days = from > first.end_of_month ? [] : patient_availability.days_with_slots(from: from, to: first.end_of_month)
    { month: params[:month], timezone: patient_availability.timezone, days: days.map(&:iso8601) }
  end

  def day_payload
    date = Date.iso8601(params.require(:date))
    { date: date.iso8601, timezone: patient_availability.timezone,
      slots: patient_availability.slots(date: date).map { |slot| slot_payload(slot) } }
  end

  def slot_payload(slot)
    { starts_at: slot[:starts_at].iso8601,
      resources: slot[:resources].map { |resource| { id: resource.id, name: resource.name, type: resource.resource_type } } }
  end

  def render_not_allowed
    render json: { message: 'Rescheduling is not allowed for this appointment' }, status: :unprocessable_entity
  end

  def enforce_rate_limit
    return if KanbanCalendar::PublicBookingRateLimiter.new(booking_page: booking_page, remote_ip: request.remote_ip).allowed?

    render json: { message: 'Too many booking attempts' }, status: :too_many_requests
  end
end
