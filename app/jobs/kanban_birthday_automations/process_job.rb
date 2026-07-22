class KanbanBirthdayAutomations::ProcessJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    KanbanBirthdayAutomation.where(active: true).find_each do |automation|
      KanbanBirthdayAutomations::ProcessService.new(automation: automation).perform!
    end
  end
end
