class KanbanAutomations::MarkExecutionFailedService
  def initialize(error:, execution_id: nil, rule_id: nil, event_key: nil)
    @error = error
    @execution_id = execution_id
    @rule_id = rule_id
    @event_key = event_key
  end

  def perform!
    execution = find_execution
    return if execution.blank?

    execution.with_lock do
      next unless execution.queued? || execution.running? || execution.waiting?

      execution.update!(status: :failed, error_message: error.message, completed_at: Time.current)
    end
  end

  private

  attr_reader :error, :execution_id, :rule_id, :event_key

  def find_execution
    return KanbanAutomationExecution.find_by(id: execution_id) if execution_id.present?

    KanbanAutomationExecution.find_by(kanban_automation_rule_id: rule_id, event_key: event_key)
  end
end
