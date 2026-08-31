class Api::V1::Accounts::Calendar::ResourcesController < Api::V1::Accounts::BaseController
  before_action :fetch_calendar_resource, only: [:show, :update, :destroy]

  def index
    authorize KanbanCalendarResource, :index?
    render json: policy_scope(KanbanCalendarResource).order(:name).map { |resource| resource_payload(resource) }
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
    @calendar_resource.update!(resource_params)
    render json: resource_payload(@calendar_resource)
  rescue ActiveRecord::RecordInvalid => e
    render_invalid_record(e.record)
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
    params.require(:resource).permit(:name, :resource_type, :user_id, :timezone, :capacity, :active, settings: {})
  end

  def resource_payload(resource)
    {
      id: resource.id,
      name: resource.name,
      resource_type: resource.resource_type,
      user_id: resource.user_id,
      timezone: resource.timezone,
      capacity: resource.capacity,
      settings: resource.settings,
      active: resource.active
    }
  end

  def render_invalid_record(record)
    render json: { message: record.errors.full_messages.to_sentence, errors: record.errors }, status: :unprocessable_entity
  end
end
