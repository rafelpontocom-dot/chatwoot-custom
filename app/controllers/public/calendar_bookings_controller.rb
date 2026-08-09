class Public::CalendarBookingsController < PublicController
  before_action :fetch_booking_page, except: [:private_show, :private_procedure, :private_create, :private_availability]
  before_action :fetch_procedure, only: [:procedure, :availability, :create]
  before_action :fetch_private_booking, only: [:private_show, :private_procedure, :private_create, :private_availability]
  before_action :fetch_private_procedure, only: [:private_procedure, :private_create, :private_availability]
  before_action :enforce_booking_rate_limit, only: [:create, :private_create]

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

  def availability
    date = Date.iso8601(params.require(:date))
    slots = KanbanCalendar::AvailabilitySlotsQuery.new(procedure: @procedure, resource: public_resource, date: date).call
    render json: { date: date.iso8601, slots: slots.map(&:iso8601) }
  rescue Date::Error, ActionController::ParameterMissing, ActiveRecord::RecordNotFound
    render_invalid_request
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

    date = Date.iso8601(params.require(:date))
    slots = KanbanCalendar::AvailabilitySlotsQuery.new(procedure: @procedure, resource: public_resource, date: date).call
    render json: { date: date.iso8601, slots: slots.map(&:iso8601) }
  rescue Date::Error, ActionController::ParameterMissing, ActiveRecord::RecordNotFound
    render_invalid_request
  end

  private

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
      resource_ids: [], custom_attributes: {}
    )
  end

  def page_payload
    {
      title: @booking_page.title.presence || @booking_page.account.name,
      description: @booking_page.description,
      locale: @booking_page.account.locale,
      public_form_fields: @booking_page.public_form_fields,
      captcha_site_key: @booking_page.captcha_site_key,
      procedures: public_procedures.map { |procedure| procedure_payload(procedure) }
    }
  end

  def procedure_payload(procedure = @procedure, include_resources: false)
    payload = {
      slug: procedure.public_slug,
      title: procedure.public_title.presence || procedure.name,
      description: procedure.public_description,
      duration_minutes: procedure.duration_minutes,
      color: procedure.color,
      recurrence_allowed: procedure.recurrence_allowed,
      max_sessions: procedure.max_sessions
    }
    payload[:resources] = public_resources.map { |resource| { id: resource.id, name: resource.name } } if include_resources
    payload
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
