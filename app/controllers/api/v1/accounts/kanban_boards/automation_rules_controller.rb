# rubocop:disable Metrics/ClassLength -- Rule lifecycle, execution diagnostics, and version recovery share one authorization boundary.
class Api::V1::Accounts::KanbanBoards::AutomationRulesController < Api::V1::Accounts::BaseController
  before_action :fetch_kanban_board
  before_action :authorize_kanban_board
  before_action :fetch_rule, only: [:update, :destroy, :test, :executions, :versions, :restore_version, :cancel_execution, :run, :retry_execution]

  def index
    render json: @kanban_board.kanban_automation_rules.ordered.map { |rule| rule_payload(rule) }
  end

  def create
    rule = @kanban_board.kanban_automation_rules.new(rule_attributes.merge(account: Current.account))
    rule.save!
    rule.record_version!
    render json: rule_payload(rule), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { message: e.record.errors.full_messages.to_sentence, errors: e.record.errors }, status: :unprocessable_entity
  end

  def update
    @rule.transaction do
      @rule.update!(rule_attributes)
      cancel_waiting_executions if cancel_waiting_executions?
      @rule.record_version!
    end
    render json: rule_payload(@rule)
  rescue ActiveRecord::RecordInvalid => e
    render json: { message: e.record.errors.full_messages.to_sentence, errors: e.record.errors }, status: :unprocessable_entity
  end

  def destroy
    @rule.destroy!
    head :no_content
  end

  def versions
    render json: @rule.kanban_automation_rule_versions.order(version_number: :desc).map { |version| version_payload(version) }
  end

  def restore_version
    version = @rule.kanban_automation_rule_versions.find(params[:version_id])
    @rule.transaction { @rule.restore_version!(version) }
    render json: rule_payload(@rule)
  rescue ActiveRecord::RecordInvalid => e
    render json: { message: e.record.errors.full_messages.to_sentence, errors: e.record.errors }, status: :unprocessable_entity
  end

  def test
    card = @kanban_board.kanban_cards.active.find(params[:card_id])
    matches = KanbanAutomations::ConditionsMatcher.new(rule: @rule, card: card).matches?
    render json: {
      matches: matches,
      card_id: card.id,
      steps: KanbanAutomations::WorkflowPreviewService.new(rule: @rule, card: card).perform,
      message: matches ? 'The opportunity matches this rule.' : 'The opportunity does not match this rule.'
    }
  end

  def all_executions
    executions = KanbanAutomationExecution
                 .joins(:kanban_automation_rule)
                 .where(kanban_automation_rules: { kanban_board_id: @kanban_board.id })
                 .includes(:kanban_automation_rule, :kanban_card_event)
                 .order(created_at: :desc, id: :desc)
                 .limit(100)
    render json: executions.map { |execution| execution_payload(execution) }
  end

  def executions
    executions = @rule.kanban_automation_executions.order(created_at: :desc, id: :desc).limit(50)
    render json: executions.map { |execution| execution_payload(execution) }
  end

  def cancel_execution
    execution = @rule.kanban_automation_executions.waiting.find(params[:execution_id])
    execution.with_lock do
      execution.update!(
        status: :skipped,
        scheduled_at: nil,
        completed_at: Time.current,
        action_results: Array(execution.action_results) + [{ 'status' => 'skipped', 'reason' => 'cancelled_by_administrator' }]
      )
    end
    render json: execution_payload(execution)
  end

  def run
    card = @kanban_board.kanban_cards.active.find(params[:card_id])
    KanbanAutomations::ExecuteRuleJob.perform_later(
      @rule.id,
      Events::Types::KANBAN_CARD_MANUAL_STARTED,
      "manual:#{SecureRandom.uuid}",
      card.id
    )
    head :accepted
  end

  def retry_execution
    execution = @rule.kanban_automation_executions.find(params[:execution_id])
    unless execution.failed? || execution.skipped?
      return render json: { message: 'Only failed or skipped executions can be retried' }, status: :unprocessable_entity
    end

    card = execution.kanban_card || execution.kanban_card_event&.kanban_card
    return render json: { message: 'Opportunity is no longer available' }, status: :unprocessable_entity if card.blank?

    KanbanAutomations::ExecuteRuleJob.perform_later(@rule.id, execution.event_name, "retry:#{execution.id}:#{SecureRandom.uuid}", card.id)
    head :accepted
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
      :reentry_enabled,
      :cancel_waiting_executions,
      :position,
      flow_definition: {},
      conditions: [
        { inbox_ids: [], stage_ids: [], owner_ids: [], fields: [:field_key, :operator, :value] }
      ],
      actions: [:action_name, { action_params: {} }]
    )
  end

  def rule_attributes
    rule_params.except(:cancel_waiting_executions)
  end

  def rule_payload(rule)
    {
      id: rule.id,
      name: rule.name,
      description: rule.description,
      event_name: rule.event_name,
      active: rule.active,
      version: rule.version_number,
      reentry_enabled: rule.reentry_enabled,
      position: rule.position,
      conditions: rule.conditions,
      actions: rule.actions,
      flow_definition: rule.flow_definition,
      executions_count: rule.kanban_automation_executions.count,
      waiting_executions_count: rule.kanban_automation_executions.waiting.count,
      last_execution: rule.kanban_automation_executions.order(created_at: :desc, id: :desc).first&.then { |execution| execution_payload(execution) }
    }
  end

  def cancel_waiting_executions?
    ActiveModel::Type::Boolean.new.cast(rule_params[:cancel_waiting_executions])
  end

  def cancel_waiting_executions
    @rule.kanban_automation_executions.waiting.find_each do |execution|
      execution.with_lock do
        execution.update!(
          status: :skipped,
          scheduled_at: nil,
          completed_at: Time.current,
          action_results: Array(execution.action_results) + [
            { 'status' => 'skipped', 'reason' => 'cancelled_after_rule_update' }
          ]
        )
      end
    end
  end

  def execution_payload(execution)
    {
      id: execution.id,
      event_name: execution.event_name,
      event_key: execution.event_key,
      status: execution.status,
      action_results: execution.action_results,
      error_message: execution.error_message,
      scheduled_at: execution.scheduled_at&.iso8601,
      started_at: execution.started_at&.iso8601,
      completed_at: execution.completed_at&.iso8601,
      created_at: execution.created_at.iso8601,
      card_id: execution.kanban_card_id || execution.kanban_card_event&.kanban_card_id,
      rule_id: execution.kanban_automation_rule_id,
      rule_name: execution.kanban_automation_rule.name
    }
  end

  def version_payload(version)
    snapshot = version.snapshot.to_h
    {
      id: version.id,
      version: version.version_number,
      name: snapshot['name'],
      event_name: snapshot['event_name'],
      active: snapshot['active'],
      created_at: version.created_at.iso8601
    }
  end
end
# rubocop:enable Metrics/ClassLength
