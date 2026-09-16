# Disponibilidade: os horários com nome da conta. Criar uma agenda passa a ser
# escolher um destes.
class Api::V1::Accounts::Calendar::SchedulesController < Api::V1::Accounts::BaseController
  include CalendarWorkingHoursParams

  before_action :fetch_schedule, except: [:index, :create]
  before_action :authorize_configure, except: [:index, :show]

  def index
    authorize KanbanCalendarResource, :index?
    schedules = Current.account.kanban_calendar_schedules.shared.includes(:kanban_calendar_availability_rules).order(:name)
    render json: schedules.map { |schedule| schedule_payload(schedule) }
  end

  def show
    authorize KanbanCalendarResource, :show?
    render json: schedule_payload(@schedule)
  end

  def create
    schedule = Current.account.kanban_calendar_schedules.create!(schedule_params)
    KanbanCalendar::WorkingHoursSheet.new(schedule.kanban_calendar_availability_rules).replace!(**working_hours_params) if sheet_given?
    render json: schedule_payload(schedule.reload), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_invalid_record(e.record)
  end

  def update
    @schedule.update!(schedule_params)
    render json: schedule_payload(@schedule)
  rescue ActiveRecord::RecordInvalid => e
    render_invalid_record(e.record)
  end

  # Horário em uso não se apaga: as agendas ficariam sem saber quando atendem.
  def destroy
    if @schedule.kanban_calendar_resources.exists?
      return render json: { message: 'This schedule is used by agendas', resources_count: @schedule.kanban_calendar_resources.count },
                    status: :unprocessable_entity
    end

    @schedule.destroy!
    head :no_content
  end

  def rules
    KanbanCalendar::WorkingHoursSheet.new(@schedule.kanban_calendar_availability_rules).replace!(**working_hours_params)
    render json: schedule_payload(@schedule.reload)
  rescue ActiveRecord::RecordInvalid => e
    render_invalid_record(e.record)
  rescue ArgumentError
    render json: { message: 'Invalid working hours' }, status: :unprocessable_entity
  end

  # Com `dry_run`, só conta as consultas futuras que ficariam fora do novo horário,
  # para a tela avisar antes; sem ele, aplica.
  def apply_to
    resources = policy_scope(KanbanCalendarResource).where(id: Array(params[:resource_ids]))
    outside = KanbanCalendar::ScheduleApplier.new(schedule: @schedule, resources: resources).appointments_outside
    return render json: { appointments_outside: outside } if ActiveModel::Type::Boolean.new.cast(params[:dry_run])

    resources.find_each { |resource| resource.update!(kanban_calendar_schedule: @schedule) }
    render json: schedule_payload(@schedule.reload).merge(appointments_outside: outside)
  end

  private

  def fetch_schedule
    @schedule = Current.account.kanban_calendar_schedules.shared.find(params[:id])
  end

  def authorize_configure
    authorize KanbanCalendarResource, :configure?
  end

  def schedule_params
    params.require(:schedule).permit(:name, :timezone, :default_schedule)
  end

  def sheet_given?
    params.key?(:weekly) || params.key?(:overrides)
  end

  def schedule_payload(schedule)
    {
      id: schedule.id,
      name: schedule.name,
      timezone: schedule.timezone,
      default: schedule.default_schedule,
      resources_count: schedule.kanban_calendar_resources.count,
      resources: schedule.kanban_calendar_resources.order(:name).map { |resource| { id: resource.id, name: resource.name } }
    }.merge(KanbanCalendar::WorkingHoursSheet.new(schedule.kanban_calendar_availability_rules).payload)
  end

  def render_invalid_record(record)
    render json: { message: record.errors.full_messages.to_sentence, errors: record.errors }, status: :unprocessable_entity
  end
end
