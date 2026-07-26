class KanbanCadences::ProcessDueJob < ApplicationJob
  BATCH_SIZE = 100

  queue_as :scheduled_jobs

  def perform
    KanbanCadenceEnrollment.due.includes(:kanban_card, :kanban_cadence).find_each(batch_size: BATCH_SIZE) do |enrollment|
      KanbanCadences::AdvanceService.new(enrollment).call
    rescue StandardError => e
      Rails.logger.error("Kanban cadence #{enrollment.id} failed: #{e.message}")
    end
  end
end
