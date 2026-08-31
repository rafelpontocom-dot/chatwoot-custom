class Api::V1::Accounts::Calendar::ProceduresController < Api::V1::Accounts::BaseController
  PROCEDURE_SCALAR_PARAMS = %i[
    name color duration_minutes buffer_before_minutes buffer_after_minutes
    location_type recurrence_allowed max_sessions active public_booking_enabled
    public_title public_description public_slug
  ].freeze

  before_action :fetch_procedure, only: [:show, :update, :destroy]

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

  # Mesmo critério das agendas: apaga quando é seguro, arquiva quando há
  # consulta marcada, e devolve qual dos dois aconteceu.
  def destroy
    authorize @procedure, :configure?

    if @procedure.kanban_calendar_appointments.exists?
      @procedure.update!(active: false)
      render json: procedure_payload(@procedure).merge(outcome: 'archived')
    else
      @procedure.destroy!
      render json: { id: @procedure.id, outcome: 'deleted' }
    end
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotDestroyed => e
    render_invalid_record(e.record)
  end

  private

  def fetch_procedure
    @procedure = policy_scope(KanbanCalendarProcedure).find(params[:id])
  end

  def procedure_params
    normalize_resource_ids(permitted_procedure_params)
  end

  def permitted_procedure_params
    params.require(:procedure).permit(
      *PROCEDURE_SCALAR_PARAMS,
      allowed_intervals: [],
      board_ids: [],
      resource_ids: [],
      stage_policy: {},
      public_booking_config: {}
    )
  end

  def normalize_resource_ids(attributes)
    return attributes unless attributes.key?(:resource_ids)

    attributes[:kanban_calendar_resource_ids] = attributes.delete(:resource_ids)
    attributes
  end

  def procedure_payload(procedure)
    procedure_attributes(procedure).merge(public_booking_payload(procedure))
  end

  def procedure_attributes(procedure)
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

  def public_booking_payload(procedure)
    {
      public_booking_enabled: procedure.public_booking_enabled,
      public_title: procedure.public_title,
      public_description: procedure.public_description,
      public_slug: procedure.public_slug,
      public_booking_config: procedure.public_booking_config
    }
  end

  def render_invalid_record(record)
    render json: { message: record.errors.full_messages.to_sentence, errors: record.errors }, status: :unprocessable_entity
  end
end
