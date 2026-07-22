class Api::V1::Accounts::KanbanBoards::AutomationRulesController < Api::V1::Accounts::BaseController
  before_action :fetch_kanban_board
  before_action :authorize_kanban_board
  before_action :fetch_rule, only: [:update, :destroy, :test, :executions]

  def index
    render json: @kanban_board.kanban_automation_rules.ordered.map { |rule| rule_payload(rule) }
  end

  def create
    rule = @kanban_board.kanban_automation_rules.new(rule_params.merge(account: Current.account))
    rule.save!
    render json: rule_payload(rule), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { message: e.record.errors.full_messages.to_sentence, errors: e.record.errors }, status: :unprocessable_entity
  end

  def update
    @rule.update!(rule_params)
    render json: rule_payload(@rule)
  rescue ActiveRecord::RecordInvalid => e
    render json: { message: e.record.errors.full_messages.to_sentence, errors: e.record.errors }, status: :unprocessable_entity
  end

  def destroy
    @rule.destroy!
    head :no_content
  end

  def test
    card = @kanban_board.kanban_cards.active.find(params[:card_id])
    matches = KanbanAutomations::ConditionsMatcher.new(rule: @rule, card: card).matches?
    render json: {
      matches: matches,
      card_id: card.id,
      message: matches ? 'The opportunity matches this rule.' : 'The opportunity does not match this rule.'
    }
  end

  def executions
    executions = @rule.kanban_automation_executions.order(created_at: :desc, id: :desc).limit(50)
    render json: executions.map { |execution| execution_payload(execution) }
  end

  private

  def fetch_kanban_board
    @kanban_board = policy_scope(KanbanBoard).find(params[:kanban_board_id])
  end

  def authorize_kanban_board
    authorize @kanban_board, :update?
  end

  def fetch_rule
    @rule = @kanban_board.kanban_automation_rules.find(params[:id])
  end

  def rule_params
    params.require(:kanban_automation_rule).permit(
      :name,
      :description,
      :event_name,
      :active,
      :position,
      conditions: [
        { inbox_ids: [], stage_ids: [], owner_ids: [], fields: [:field_key, :operator, :value] }
      ],
      actions: [:action_name, { action_params: {} }]
    )
  end

  def rule_payload(rule)
    {
      id: rule.id,
      name: rule.name,
      description: rule.description,
      event_name: rule.event_name,
      active: rule.active,
      position: rule.position,
      conditions: rule.conditions,
      actions: rule.actions,
      executions_count: rule.kanban_automation_executions.count,
      last_execution: rule.kanban_automation_executions.order(created_at: :desc, id: :desc).first&.then { |execution| execution_payload(execution) }
    }
  end

  def execution_payload(execution)
    {
      id: execution.id,
      event_name: execution.event_name,
      event_key: execution.event_key,
      status: execution.status,
      action_results: execution.action_results,
      error_message: execution.error_message,
      started_at: execution.started_at&.iso8601,
      completed_at: execution.completed_at&.iso8601,
      created_at: execution.created_at.iso8601
    }
  end
end
