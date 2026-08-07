class Api::V1::Accounts::Calendar::ProceduresController < Api::V1::Accounts::BaseController
  before_action :fetch_procedure, only: [:show, :update]

  def index
    authorize KanbanCalendarProcedure, :index?
    render json: policy_scope(KanbanCalendarProcedure).order(:name).map { |procedure| procedure_payload(procedure) }
  end

  def show
    authorize @procedure, :show?
    render json: procedure_payload(@procedure)
  end

  def create
    procedure = Current.account.kanban_calendar_procedures.new(procedure_params)
    authorize procedure, :configure?
    procedure.save!
    render json: procedure_payload(procedure), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_invalid_record(e.record)
  end

  def update
    authorize @procedure, :configure?
    @procedure.update!(procedure_params)
    render json: procedure_payload(@procedure)
  rescue ActiveRecord::RecordInvalid => e
    render_invalid_record(e.record)
  end

  private

  def fetch_procedure
    @procedure = policy_scope(KanbanCalendarProcedure).find(params[:id])
  end

  def procedure_params
    params.require(:procedure).permit(
      :name,
      :color,
      :duration_minutes,
      :buffer_before_minutes,
      :buffer_after_minutes,
      :location_type,
      :recurrence_allowed,
      :max_sessions,
      :active,
      allowed_intervals: [],
      board_ids: [],
      resource_ids: [],
      stage_policy: {}
    ).tap do |attributes|
      attributes[:kanban_calendar_resource_ids] = attributes.delete(:resource_ids) if attributes.key?(:resource_ids)
    end
  end

  def procedure_payload(procedure)
    {
      id: procedure.id,
      name: procedure.name,
      color: procedure.color,
      duration_minutes: procedure.duration_minutes,
      buffer_before_minutes: procedure.buffer_before_minutes,
      buffer_after_minutes: procedure.buffer_after_minutes,
      location_type: procedure.location_type,
      recurrence_allowed: procedure.recurrence_allowed,
      max_sessions: procedure.max_sessions,
      allowed_intervals: procedure.allowed_intervals,
      board_ids: procedure.board_ids,
      resource_ids: procedure.kanban_calendar_resource_ids,
      stage_policy: procedure.stage_policy,
      active: procedure.active
    }
  end

  def render_invalid_record(record)
    render json: { message: record.errors.full_messages.to_sentence, errors: record.errors }, status: :unprocessable_entity
  end
end
