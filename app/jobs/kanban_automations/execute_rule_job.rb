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
        kanban_card_event_id: event_id
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
    @execution.succeeded? || @execution.running?
  end

  def execute_with_lock
    @execution.with_lock do
      next if execution_finished?

      @execution.update!(status: :running, started_at: Time.current, error_message: nil)
      next skip_execution unless conditions_match?

      results = KanbanAutomations::ActionService.new(rule: @rule, card: @card).perform!
      @execution.update!(status: :succeeded, action_results: results, completed_at: Time.current)
    end
  end

  def skip_execution
    @execution.update!(status: :skipped, completed_at: Time.current)
  end

  def conditions_match?
    KanbanAutomations::ConditionsMatcher.new(rule: @rule, card: @card).matches?
  end
end
