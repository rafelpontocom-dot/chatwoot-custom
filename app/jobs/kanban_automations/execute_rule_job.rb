class KanbanAutomations::ExecuteRuleJob < ApplicationJob
  queue_as :critical

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(rule_id, event_name, event_key, card_id, event_id = nil)
    load_context(rule_id, card_id)
    return if context_missing?

    @execution = find_or_create_execution(event_name, event_key, event_id)
    return if execution_finished?

    execute_with_lock
  rescue StandardError => e
    @execution&.update(status: :failed, error_message: e.message, completed_at: Time.current)
    raise
  end

  private

  def find_or_create_execution(event_name, event_key, event_id)
    @rule.kanban_automation_executions.create_or_find_by!(event_key: event_key) do |execution|
      execution.assign_attributes(
        account: @rule.account,
        event_name: event_name,
        kanban_card_event_id: event_id,
        kanban_card: @card,
        automation_snapshot: automation_snapshot
      )
    end
  end

  def load_context(rule_id, card_id)
    @rule = KanbanAutomationRule.active.find_by(id: rule_id)
    @card = KanbanCard.find_by(id: card_id)
  end

  def context_missing?
    @rule.blank? || @card.blank?
  end

  def execution_finished?
    @execution.succeeded? || @execution.running? || @execution.waiting?
  end

  def execute_with_lock
    @execution.with_lock do
      next if execution_finished?

      @execution.update!(status: :running, started_at: Time.current, error_message: nil)
      next skip_execution('active_execution_exists') if active_execution_exists?
      next skip_execution('reentry_not_allowed') if completed_execution_exists? && !@rule.reentry_enabled?
      next skip_execution unless conditions_match?

      if @rule.visual_flow?
        execute_visual_workflow
      else
        results = KanbanAutomations::ActionService.new(
          rule: @rule,
          card: @card,
          actions: automation_snapshot['actions']
        ).perform!
        @execution.update!(status: :succeeded, action_results: results, completed_at: Time.current)
      end
    end
  end

  def skip_execution(reason = nil)
    action_results = Array(@execution.action_results)
    action_results << { 'status' => 'skipped', 'reason' => reason } if reason.present?
    @execution.update!(status: :skipped, completed_at: Time.current, action_results: action_results)
  end

  def active_execution_exists?
    @rule.kanban_automation_executions
         .where(kanban_card_id: @card.id, status: %w[queued running waiting])
         .where.not(id: @execution.id)
         .exists?
  end

  def completed_execution_exists?
    @rule.kanban_automation_executions
         .where(kanban_card_id: @card.id, status: :succeeded)
         .where.not(id: @execution.id)
         .exists?
  end

  def conditions_match?
    KanbanAutomations::ConditionsMatcher.new(
      rule: @rule,
      card: @card,
      conditions: automation_snapshot['conditions']
    ).matches?
  end

  def execute_visual_workflow
    result = KanbanAutomations::WorkflowService.new(execution: @execution, rule: @rule, card: @card).perform!
    @execution.update!(
      status: result.fetch(:status),
      action_results: result.fetch(:action_results),
      workflow_state: result.fetch(:workflow_state),
      scheduled_at: result.fetch(:scheduled_at),
      completed_at: result[:status] == :succeeded ? Time.current : nil
    )
    return unless result[:status] == :waiting

    KanbanAutomations::ContinueWorkflowJob.set(wait_until: result.fetch(:scheduled_at)).perform_later(@execution.id, @card.id)
  end

  def automation_snapshot
    @automation_snapshot ||= {
      'version' => @rule.lock_version,
      'conditions' => @rule.conditions,
      'actions' => @rule.actions,
      'flow_definition' => @rule.flow_definition
    }
  end
end
