# rubocop:disable Metrics/ClassLength -- Public and private booking links share the same three-step flow.
class Public::CalendarBookingsController < PublicController
  PRIVATE_ACTIONS = %i[private_show private_procedure private_create private_availability private_hold private_confirm].freeze

  before_action :fetch_booking_page, except: PRIVATE_ACTIONS
  before_action :fetch_procedure, only: [:procedure, :availability, :create, :hold, :confirm]
  before_action :fetch_private_booking, only: PRIVATE_ACTIONS
  before_action :fetch_private_procedure, only: PRIVATE_ACTIONS - [:private_show]
  before_action :enforce_booking_rate_limit, only: [:create, :private_create, :hold, :private_hold, :confirm, :private_confirm]

  def show
    respond_to do |format|
      format.html { render :show, layout: 'public_calendar_booking' }
      format.json { render json: page_payload }
    end
  end

  def procedure
    respond_to do |format|
      format.html { render :show, layout: 'public_calendar_booking' }
      format.json { render json: procedure_payload(include_resources: true) }
    end
  end

  # `month` devolve os dias com vaga (o calendário do mês); `date`, os horários
  # do dia com quem atende. `resource_id` mantém o contrato antigo.
  def availability
    return render json: legacy_resource_availability if params[:resource_id].present?
    return render json: month_availability if params[:month].present?

    render json: day_availability
  rescue ActionController::ParameterMissing, ActiveRecord::RecordNotFound, ArgumentError
    render_invalid_request
  end

  # Passo 1 → 2: segura o horário enquanto o paciente preenche os dados.
  def hold
    hold = KanbanCalendar::PublicSlotHoldService.new(
      procedure: @procedure, starts_at: Time.zone.parse(params.require(:starts_at)),
      timezone: params[:timezone].presence || patient_availability.timezone, professional_id: params[:professional_id]
    ).perform!
    render json: hold_payload(hold), status: :created
  rescue KanbanCalendar::ConflictError
    render json: { message: 'This time is no longer available', code: 'slot_taken' }, status: :conflict
  rescue ActionController::ParameterMissing, ArgumentError, ActiveRecord::RecordInvalid
    render_invalid_request
  end

  # Passo 2 → 3: dados do paciente e forma de pagamento.
  def confirm
    return render_invalid_request if rejected_submission?

    render_confirmed_appointment
  rescue ActiveRecord::RecordNotFound
    render_hold_expired
  rescue KanbanCalendar::ConflictError
    render json: { message: 'This time is no longer available', code: 'slot_taken' }, status: :conflict
  rescue KanbanCalendar::BookingPaymentService::PaymentUnavailable, Finance::Asaas::ApiError => e
    render json: { message: e.message, code: 'payment_failed' }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    e.record.errors.full_messages.include?('The held time has expired') ? render_hold_expired : render_invalid_request
  rescue ActionController::ParameterMissing
    render_invalid_request
  end

  def private_hold
    return render json: { message: 'Booking link not found' }, status: :not_found unless @booking_link.available?

    hold
  end

  def private_confirm
    return render json: { message: 'Booking link not found' }, status: :not_found unless @booking_link.available?

    confirm
    @booking_link.consume! if response.created?
  end

  def create
    return render_invalid_request unless booking_params[:consent] == true
    return render_invalid_request if booking_params[:website].present?
    return render_invalid_request if captcha_required? && !captcha_valid?

    render_created_appointment
  rescue KanbanCalendar::ConflictError
    render json: { message: 'This time is no longer available' }, status: :conflict
  rescue ActiveRecord::RecordInvalid, ActionController::ParameterMissing
    render_invalid_request
  end

  def private_show
    return render json: { message: 'Booking link not found' }, status: :not_found unless @booking_link.available?

    respond_to do |format|
      format.html { render :show, layout: 'public_calendar_booking' }
      format.json do
        payload = page_payload
        payload[:procedure] = procedure_payload(@procedure, include_resources: true) if @procedure
        render json: payload
      end
    end
  end

  def private_procedure
    return render json: { message: 'Booking link not found' }, status: :not_found unless @booking_link.available?

    respond_to do |format|
      format.html { render :show, layout: 'public_calendar_booking' }
      format.json { render json: procedure_payload(include_resources: true) }
    end
  end

  def private_create
    return render json: { message: 'Booking link not found' }, status: :not_found unless @booking_link.available?

    create
    @booking_link.consume! if response.created?
  end

  def private_availability
    return render json: { message: 'Booking link not found' }, status: :not_found unless @booking_link.available?

    availability
  end

  private

  def rejected_submission?
    booking_params[:consent] != true || booking_params[:website].present? || (captcha_required? && !captcha_valid?)
  end

  def render_hold_expired
    render json: { message: 'The held time has expired', code: 'hold_expired' }, status: :conflict
  end

  def fetch_booking_page
    @booking_page = KanbanCalendarBookingPage.find_by!(public_token: params[:public_token], active: true)
  rescue ActiveRecord::RecordNotFound
    render json: { message: 'Booking page not found' }, status: :not_found
  end

  def fetch_procedure
    @procedure = @booking_page.account.kanban_calendar_procedures.active.find_by!(
      public_booking_enabled: true,
      public_slug: params[:procedure_slug]
    )
  rescue ActiveRecord::RecordNotFound
    render json: { message: 'Booking page not found' }, status: :not_found
  end

  def find_booking_link!
    KanbanCalendarBookingLink.includes(
      :kanban_calendar_booking_page,
      :kanban_calendar_procedure
    ).find_by!(token: params[:private_token])
  end

  def fetch_private_booking
    @booking_link = find_booking_link!
    @booking_page = @booking_link.kanban_calendar_booking_page
    @procedure = @booking_link.kanban_calendar_procedure
  rescue ActiveRecord::RecordNotFound
    render json: { message: 'Booking link not found' }, status: :not_found
  end

  def fetch_private_procedure
    return if @procedure && params[:procedure_slug].blank?

    requested_procedure = @booking_page.account.kanban_calendar_procedures.active.find_by!(
      public_booking_enabled: true,
      public_slug: params.require(:procedure_slug)
    )
    raise ActiveRecord::RecordNotFound if @procedure && requested_procedure.id != @procedure.id

    @procedure = requested_procedure
  rescue ActiveRecord::RecordNotFound, ActionController::ParameterMissing
    render json: { message: 'Booking link not found' }, status: :not_found
  end

  def booking_params
    params.require(:booking).permit(
      :name, :email, :phone_number, :starts_at, :timezone, :consent, :website, :captcha_token,
      :cpf, :notes, :payment_method, resource_ids: [], custom_attributes: {}
    )
  end

  def page_payloads
    @page_payloads ||= KanbanCalendar::PublicPagePayload.new(booking_page: @booking_page)
  end

  def page_payload
    page_payloads.page(procedures: public_procedures)
  end

  def procedure_payload(procedure = @procedure, include_resources: false)
    return page_payloads.procedure_summary(procedure) unless include_resources

    page_payloads.procedure_detail(procedure, resources: public_resources)
  end

  def patient_availability
    @patient_availability ||= KanbanCalendar::ProcedureAvailability.new(
      procedure: @procedure, professional_id: params[:professional_id], patient: true
    )
  end

  def legacy_resource_availability
    date = Date.iso8601(params.require(:date))
    slots = KanbanCalendar::AvailabilitySlotsQuery.new(procedure: @procedure, resource: public_resource, date: date).call
    { date: date.iso8601, slots: slots.map(&:iso8601) }
  end

  def month_availability
    first = Date.strptime(params.require(:month), '%Y-%m')
    today = Time.current.in_time_zone(patient_availability.timezone).to_date
    from = [first, today].max
    days = from > first.end_of_month ? [] : patient_availability.days_with_slots(from: from, to: first.end_of_month)
    { month: first.strftime('%Y-%m'), timezone: patient_availability.timezone, days: days.map(&:iso8601) }
  end

  def day_availability
    date = Date.iso8601(params.require(:date))
    {
      date: date.iso8601,
      timezone: patient_availability.timezone,
      slots: patient_availability.slots(date: date).map do |slot|
        { starts_at: slot[:starts_at].iso8601, resources: slot[:resources].map { |resource| public_resource_payload(resource) } }
      end
    }
  end

  def public_resource_payload(resource)
    { id: resource.id, name: resource.name, type: resource.resource_type }
  end

  def hold_payload(hold)
    resources = @booking_page.account.kanban_calendar_resources.where(id: hold.resource_ids).order(:name)
    {
      token: hold.token, starts_at: hold.starts_at.iso8601, expires_at: hold.expires_at.iso8601, timezone: hold.timezone,
      ends_at: (hold.starts_at + @procedure.duration_minutes.minutes).iso8601,
      resources: resources.map { |resource| public_resource_payload(resource) }
    }
  end

  def public_procedures
    @booking_page.account.kanban_calendar_procedures.active.where(public_booking_enabled: true).order(:name)
  end

  def public_resources
    scope = @booking_page.account.kanban_calendar_resources.active.order(:name)
    return scope unless @procedure.kanban_calendar_resources.exists?

    scope.where(id: @procedure.kanban_calendar_resource_ids)
  end

  def public_resource
    public_resources.find(params.require(:resource_id))
  end

  def render_invalid_request
    render json: { message: 'Invalid booking request' }, status: :unprocessable_entity
  end

  def captcha_required?
    @booking_page.captcha_provider.present?
  end

  def captcha_valid?
    return false unless @booking_page.captcha_provider == 'turnstile'

    KanbanCalendar::TurnstileVerificationService.new(
      token: booking_params[:captcha_token],
      remote_ip: request.remote_ip
    ).valid?
  end

  def enforce_booking_rate_limit
    return if KanbanCalendar::PublicBookingRateLimiter.new(booking_page: @booking_page, remote_ip: request.remote_ip).allowed?

    render json: { message: 'Too many booking attempts' }, status: :too_many_requests
  end

  def render_confirmed_appointment
    hold = KanbanCalendarSlotHold.find_by!(token: params[:hold_token], kanban_calendar_procedure_id: @procedure.id)
    appointment = KanbanCalendar::PublicBookingService.new(
      booking_page: @booking_page,
      procedure: @procedure,
      booking: {
        hold: hold,
        contact_attributes: booking_params.slice(:name, :email, :phone_number, :custom_attributes),
        timezone: booking_params[:timezone], notes: booking_params[:notes],
        payment_method: booking_params[:payment_method], cpf: booking_params[:cpf]
      }
    ).perform!
    render json: KanbanCalendar::PatientBookingPayload.new(appointment: appointment.reload).call, status: :created
  end

  def render_created_appointment
    appointment = KanbanCalendar::PublicBookingService.new(
      booking_page: @booking_page,
      procedure: @procedure,
      booking: {
        contact_attributes: booking_params.slice(:name, :email, :phone_number, :custom_attributes),
        resource_ids: booking_params[:resource_ids],
        starts_at: Time.zone.parse(booking_params[:starts_at]),
        timezone: booking_params[:timezone]
      }
    ).perform!
    render json: KanbanCalendar::AppointmentPayloadBuilder.new(appointment).call, status: :created
  end
end
# rubocop:enable Metrics/ClassLength
