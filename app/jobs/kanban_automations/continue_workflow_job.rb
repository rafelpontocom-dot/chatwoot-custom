class KanbanAutomations::ContinueWorkflowJob < ApplicationJob
  queue_as :critical

  retry_on StandardError, wait: :polynomially_longer, attempts: 3 do |job, error|
    KanbanAutomations::MarkExecutionFailedService.new(
      execution_id: job.arguments.first,
      error: error
    ).perform!
  end

  def perform(execution_id, card_id)
    execution = KanbanAutomationExecution.find_by(id: execution_id)
    card = KanbanCard.find_by(id: card_id)
    return unless execution&.waiting? && card.present?

    execution.with_lock do
      route_expired_response_wait(execution)
      resume_workflow(execution, card)
    end
  end

  private

  def resumable?(execution, card)
    execution.kanban_automation_rule.active? && card.active?
  end

  def resume_workflow(execution, card)
    return unless execution.waiting?
    return skip_execution(execution) unless resumable?(execution, card)

    execution.update!(status: :running, error_message: nil)
    result = workflow_result(execution, card)
    persist_result(execution, result)
    schedule_continuation(execution, card, result) if result[:status] == :waiting
  end

  def route_expired_response_wait(execution)
    state = execution.workflow_state.to_h
    timeout_node_id = state['timeout_node_id']
    return unless state['waiting_for'] == 'customer_message' && timeout_node_id.present?

    execution.update!(
      workflow_state: state.except('waiting_for', 'timeout_node_id').merge('next_node_id' => timeout_node_id),
      action_results: Array(execution.action_results) + [
        { 'status' => 'skipped', 'reason' => 'response_timeout', 'waiting_for' => 'customer_message' }
      ]
    )
  end

  def workflow_result(execution, card)
    KanbanAutomations::WorkflowService.new(
      execution: execution,
      rule: execution.kanban_automation_rule,
      card: card
    ).perform!
  end

  def persist_result(execution, result)
    execution.update!(
      status: result.fetch(:status),
      action_results: result.fetch(:action_results),
      workflow_state: result.fetch(:workflow_state),
      scheduled_at: result.fetch(:scheduled_at),
      completed_at: result[:status] == :succeeded ? Time.current : nil
    )
  end

  def schedule_continuation(execution, card, result)
    self.class.set(wait_until: result.fetch(:scheduled_at)).perform_later(execution.id, card.id)
  end

  def skip_execution(execution)
    execution.update!(status: :skipped, scheduled_at: nil, completed_at: Time.current)
  end
end
