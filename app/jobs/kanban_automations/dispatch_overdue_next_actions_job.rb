class KanbanAutomations::DispatchOverdueNextActionsJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    KanbanAutomations::DispatchOverdueNextActionsService.new.perform!
  end
end
