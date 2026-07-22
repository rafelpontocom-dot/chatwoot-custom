class Api::V1::Accounts::KanbanBoards::AppointmentReminderRulesController < Api::V1::Accounts::BaseController
  before_action :fetch_kanban_board
  before_action :authorize_kanban_board
  before_action :fetch_rule, only: [:update, :destroy]

  def index
    render json: @kanban_board.kanban_appointment_reminder_rules.order(:id).map { |rule| payload(rule) }
  end

  def create
    rule = @kanban_board.kanban_appointment_reminder_rules.create!(rule_params.merge(account: Current.account))
    render json: payload(rule), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { message: e.record.errors.full_messages.to_sentence, errors: e.record.errors }, status: :unprocessable_entity
  end

  def update
    @rule.update!(rule_params)
    render json: payload(@rule)
  rescue ActiveRecord::RecordInvalid => e
    render json: { message: e.record.errors.full_messages.to_sentence, errors: e.record.errors }, status: :unprocessable_entity
  end

  def destroy
    @rule.update!(active: false)
    @rule.deliveries.scheduled.update_all(status: 'canceled', updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    head :no_content
  end

  private

  def fetch_kanban_board
    @kanban_board = policy_scope(KanbanBoard).find(params[:kanban_board_id])
  end

  def authorize_kanban_board
    authorize @kanban_board, :update?
  end

  def fetch_rule
    @rule = @kanban_board.kanban_appointment_reminder_rules.find(params[:id])
  end

  def rule_params
    params.require(:appointment_reminder_rule).permit(
      :trigger_type,
      :trigger_stage_id,
      :field_key,
      :opt_in_attribute_key,
      :timezone_mode,
      :active,
      offsets: [],
      channels: [],
      message_templates: {},
      whatsapp_template_params: {}
    )
  end

  def payload(rule)
    {
      id: rule.id,
      trigger_type: rule.trigger_type,
      trigger_stage_id: rule.trigger_stage_id,
      field_key: rule.field_key,
      offsets: rule.offsets,
      channels: rule.channels,
      message_templates: rule.message_templates,
      whatsapp_template_params: rule.whatsapp_template_params,
      opt_in_attribute_key: rule.opt_in_attribute_key,
      timezone_mode: rule.timezone_mode,
      active: rule.active
    }
  end
end
