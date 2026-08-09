class Api::V1::Accounts::Calendar::ResourceAvailabilityRulesController < Api::V1::Accounts::BaseController
  before_action :fetch_calendar_resource
  before_action :fetch_rule, only: [:update, :destroy]
  before_action :authorize_resource

  def index
    render json: @calendar_resource.kanban_calendar_availability_rules.order(:kind, :weekday, :starts_at_local).map { |rule| rule_payload(rule) }
  end

  def create
    rule = @calendar_resource.kanban_calendar_availability_rules.create!(rule_params)
    render json: rule_payload(rule), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_invalid_record(e.record)
  end

  def update
    @rule.update!(rule_params)
    render json: rule_payload(@rule)
  rescue ActiveRecord::RecordInvalid => e
    render_invalid_record(e.record)
  end

  def destroy
    @rule.destroy!
    head :no_content
  end

  private

  def fetch_calendar_resource
    @calendar_resource = policy_scope(KanbanCalendarResource).find(params[:resource_id])
  end

  def fetch_rule
    @rule = @calendar_resource.kanban_calendar_availability_rules.find(params[:id])
  end

  def authorize_resource
    authorize @calendar_resource, :configure?
  end

  def rule_params
    params.require(:availability_rule).permit(:kind, :weekday, :date, :starts_at_local, :ends_at_local, :active)
  end

  def rule_payload(rule)
    {
      id: rule.id,
      kind: rule.kind,
      weekday: rule.weekday,
      date: rule.date&.iso8601,
      starts_at_local: rule.starts_at_local&.strftime('%H:%M'),
      ends_at_local: rule.ends_at_local&.strftime('%H:%M'),
      active: rule.active
    }
  end

  def render_invalid_record(record)
    render json: { message: record.errors.full_messages.to_sentence, errors: record.errors }, status: :unprocessable_entity
  end
end
