class Api::V1::Accounts::Calendar::ResourcesController < Api::V1::Accounts::BaseController
  include CalendarWorkingHoursParams

  before_action :fetch_calendar_resource, only: [:show, :update, :destroy, :working_hours, :update_working_hours]

  def index
    authorize KanbanCalendarResource, :index?
    resources = policy_scope(KanbanCalendarResource).includes(:kanban_calendar_google_connection, :kanban_calendar_schedule).order(:name)
    render json: resources.map { |resource| resource_payload(resource) }
  end

  def show
    authorize @calendar_resource, :show?
    render json: resource_payload(@calendar_resource)
  end

  def create
    resource = Current.account.kanban_calendar_resources.new(resource_params)
    authorize resource, :configure?
    resource.save!
    render json: resource_payload(resource), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_invalid_record(e.record)
  end

  def update
    authorize @calendar_resource, :configure?
    previous_schedule = @calendar_resource.kanban_calendar_schedule
    @calendar_resource.update!(resource_params)
    keep_hours_when_leaving_schedule(previous_schedule)
    render json: resource_payload(@calendar_resource)
  rescue ActiveRecord::RecordInvalid => e
    render_invalid_record(e.record)
  end

  # Horário só desta agenda, no formato do editor da semana.
  def working_hours
    authorize @calendar_resource, :show?
    render json: KanbanCalendar::WorkingHoursSheet.new(@calendar_resource.kanban_calendar_availability_rules).payload
  end

  def update_working_hours
    authorize @calendar_resource, :configure?
    sheet = KanbanCalendar::WorkingHoursSheet.new(@calendar_resource.kanban_calendar_availability_rules)
    sheet.replace!(**working_hours_params)
    render json: sheet.payload
  rescue ActiveRecord::RecordInvalid => e
    render_invalid_record(e.record)
  rescue ArgumentError
    render json: { message: 'Invalid working hours' }, status: :unprocessable_entity
  end

  # Apaga quando é seguro; arquiva quando não é, e diz qual dos dois aconteceu.
  #
  # Desativar já existia e não resolve: a agenda continua na lista para sempre.
  # Mas apagar uma agenda com consultas marcadas levaria embora o registo de
  # quem atendeu quem — por isso `restrict_with_error` no modelo. Então: sem
  # consultas, apaga de verdade; com consultas, arquiva e devolve `archived`,
  # para a interface poder explicar em vez de falhar em silêncio.
  def destroy
    authorize @calendar_resource, :configure?

    if @calendar_resource.kanban_calendar_appointments.exists?
      @calendar_resource.update!(active: false)
      render json: resource_payload(@calendar_resource).merge(outcome: 'archived')
    else
      @calendar_resource.destroy!
      render json: { id: @calendar_resource.id, outcome: 'deleted' }
    end
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotDestroyed => e
    render_invalid_record(e.record)
  end

  private

  def fetch_calendar_resource
    @calendar_resource = policy_scope(KanbanCalendarResource).find(params[:id])
  end

  def resource_params
    attributes = params.require(:resource).permit(:name, :resource_type, :user_id, :timezone, :capacity, :active,
                                                  :slot_interval_minutes, :schedule_id, settings: {})
    attributes[:kanban_calendar_schedule_id] = attributes.delete(:schedule_id) if attributes.key?(:schedule_id)
    attributes
  end

  # Quem deixa de usar um horário com nome e ainda não tem semana própria começa
  # com a semana do horário que usava, em vez de ficar sem horário nenhum.
  def keep_hours_when_leaving_schedule(previous_schedule)
    return if previous_schedule.blank? || @calendar_resource.kanban_calendar_schedule_id.present?
    return if @calendar_resource.kanban_calendar_availability_rules.exists?(kind: 'weekly_window')

    previous = KanbanCalendar::WorkingHoursSheet.new(previous_schedule.kanban_calendar_availability_rules).payload
    KanbanCalendar::WorkingHoursSheet.new(@calendar_resource.kanban_calendar_availability_rules).replace!(weekly: previous[:weekly], overrides: [])
  end

  def resource_payload(resource)
    {
      id: resource.id,
      name: resource.name,
      resource_type: resource.resource_type,
      user_id: resource.user_id,
      timezone: resource.timezone,
      capacity: resource.capacity,
      slot_interval_minutes: resource.slot_interval_minutes,
      settings: resource.settings,
      active: resource.active,
      schedule: resource.kanban_calendar_schedule&.then { |schedule| { id: schedule.id, name: schedule.name } },
      missing_hours: !resource.working_hours?,
      feegow_professional_id: resource.settings.dig('feegow', 'professional_id'),
      google_calendar_status: resource.kanban_calendar_google_connection&.status || 'disconnected'
    }
  end

  def render_invalid_record(record)
    render json: { message: record.errors.full_messages.to_sentence, errors: record.errors }, status: :unprocessable_entity
  end
end
