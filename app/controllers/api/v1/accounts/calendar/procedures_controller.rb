class Api::V1::Accounts::Calendar::ProceduresController < Api::V1::Accounts::BaseController
  PROCEDURE_SCALAR_PARAMS = %i[
    name color duration_minutes buffer_before_minutes buffer_after_minutes
    location_type recurrence_allowed max_sessions active public_booking_enabled
    public_title public_description public_slug
    availability_mode schedule_id assignment_strategy team_id
    minimum_notice_minutes maximum_notice_days slot_interval_minutes daily_limit
    payment_enabled price_cents payment_mode deposit_cents hold_minutes
    reschedule_allowed cancel_allowed change_deadline_hours cancel_reason_required on_cancel_stage_action
  ].freeze
  BOOKING_SETTINGS = %i[
    availability_mode assignment_strategy minimum_notice_minutes maximum_notice_days slot_interval_minutes daily_limit
    payment_enabled price_cents payment_mode deposit_cents payment_methods hold_minutes
    reschedule_allowed cancel_allowed change_deadline_hours cancel_reason_required on_cancel_stage_action
  ].freeze
  PREVIEW_DAYS = 14

  before_action :fetch_procedure, only: [:show, :update, :destroy, :availability_preview]

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

  # «Resultado, nas próximas duas semanas»: o que a página pública mostraria,
  # pelo mesmo caminho que ela usa.
  def availability_preview
    authorize @procedure, :show?
    days = params.fetch(:days, PREVIEW_DAYS).to_i.clamp(1, 31)
    today = Time.current.in_time_zone(Current.account.kanban_calendar_resources.first&.working_timezone || 'UTC').to_date
    availability = KanbanCalendar::ProcedureAvailability.new(procedure: @procedure, patient: true)
    render json: {
      timezone: availability.timezone,
      days: availability.upcoming(from: today, days: days, per_day: 8, max_days: days).map do |day|
        {
          date: day[:date].iso8601,
          slots: day[:slots].map { |slot| { starts_at: slot[:starts_at].iso8601, resources: slot[:resources].map(&:name) } }
        }
      end
    }
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
      payment_methods: [],
      stage_policy: {},
      public_booking_config: {}
    ).tap { |attributes| permit_booking_questions(attributes) }
  end

  # `questions` é uma lista de objetos; o `{}` acima não a deixa passar.
  def permit_booking_questions(attributes)
    questions = params.dig(:procedure, :public_booking_config, :questions)
    return if questions.nil?

    attributes[:public_booking_config] = (attributes[:public_booking_config] || {}).to_h.merge(
      'questions' => questions.map { |question| question.permit(:key, :label, :kind, :required, :locked, options: []).to_h }
                              .map { |question| question.merge('required' => cast_required(question['required'])) }
    )
  end

  def cast_required(value)
    return 'feegow' if value.to_s == 'feegow'

    ActiveModel::Type::Boolean.new.cast(value) || false
  end

  def normalize_resource_ids(attributes)
    { resource_ids: :kanban_calendar_resource_ids, schedule_id: :kanban_calendar_schedule_id, team_id: :kanban_calendar_team_id }
      .each { |from, to| attributes[to] = attributes.delete(from) if attributes.key?(from) }
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
      active: procedure.active,
      schedule_id: procedure.kanban_calendar_schedule_id,
      team_id: procedure.kanban_calendar_team_id
    }.merge(procedure.slice(*BOOKING_SETTINGS).symbolize_keys)
  end

  def public_booking_payload(procedure)
    {
      public_booking_enabled: procedure.public_booking_enabled,
      public_title: procedure.public_title,
      public_description: procedure.public_description,
      public_slug: procedure.public_slug,
      public_booking_config: procedure.public_booking_config,
      mirrors_feegow: procedure.mirrors_feegow?,
      booking_questions: procedure.booking_questions
    }
  end

  def render_invalid_record(record)
    render json: { message: record.errors.full_messages.to_sentence, errors: record.errors }, status: :unprocessable_entity
  end
end
