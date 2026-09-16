# Equipes: profissionais que atendem o mesmo procedimento, e a regra que decide
# quem fica com a consulta quando o paciente não escolhe.
class Api::V1::Accounts::Calendar::TeamsController < Api::V1::Accounts::BaseController
  before_action :fetch_team, only: [:update, :destroy]
  before_action :authorize_configure, except: [:index]

  def index
    authorize KanbanCalendarResource, :index?
    teams = Current.account.kanban_calendar_teams.includes(kanban_calendar_team_members: :kanban_calendar_resource).order(:name)
    render json: teams.map { |team| team_payload(team) }
  end

  def create
    team = Current.account.kanban_calendar_teams.new(team_params)
    ActiveRecord::Base.transaction do
      team.save!
      replace_members!(team) if params.key?(:member_ids)
    end
    render json: team_payload(team.reload), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_invalid_record(e.record)
  end

  def update
    ActiveRecord::Base.transaction do
      @team.update!(team_params)
      replace_members!(@team) if params.key?(:member_ids)
    end
    render json: team_payload(@team.reload)
  rescue ActiveRecord::RecordInvalid => e
    render_invalid_record(e.record)
  end

  def destroy
    @team.destroy!
    head :no_content
  end

  private

  def fetch_team
    @team = Current.account.kanban_calendar_teams.find(params[:id])
  end

  def authorize_configure
    authorize KanbanCalendarResource, :configure?
  end

  def team_params
    params.require(:team).permit(:name, :assignment_strategy, :active)
  end

  # Quem sai perde o lugar no rodízio; quem fica mantém o seu.
  def replace_members!(team)
    ids = Array(params[:member_ids]).map(&:to_i).uniq
    team.kanban_calendar_team_members.where.not(kanban_calendar_resource_id: ids).destroy_all
    ids.each do |resource_id|
      resource = Current.account.kanban_calendar_resources.find(resource_id)
      team.kanban_calendar_team_members.find_or_create_by!(kanban_calendar_resource: resource)
    end
  end

  def team_payload(team)
    {
      id: team.id,
      name: team.name,
      assignment_strategy: team.assignment_strategy,
      active: team.active,
      procedures_count: team.kanban_calendar_procedures.count,
      members: team.kanban_calendar_team_members.sort_by { |member| member.kanban_calendar_resource.name }.map do |member|
        resource = member.kanban_calendar_resource
        { id: resource.id, name: resource.name, active: member.active && resource.active,
          schedule_name: resource.kanban_calendar_schedule&.name }
      end
    }
  end

  def render_invalid_record(record)
    render json: { message: record.errors.full_messages.to_sentence, errors: record.errors }, status: :unprocessable_entity
  end
end
