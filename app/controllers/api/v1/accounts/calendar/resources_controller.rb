class Api::V1::Accounts::Calendar::ResourcesController < Api::V1::Accounts::BaseController
  before_action :fetch_calendar_resource, only: [:show, :update]

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
