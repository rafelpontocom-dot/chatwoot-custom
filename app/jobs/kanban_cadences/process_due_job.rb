class KanbanCadences::ProcessDueJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    KanbanCadenceEnrollment.due.includes(:kanban_card, :kanban_cadence).find_each do |enrollment|
      KanbanCadences::AdvanceService.new(enrollment).call
    rescue StandardError => e
      Rails.logger.error("Kanban cadence #{enrollment.id} failed: #{e.message}")
    end
  end
end
