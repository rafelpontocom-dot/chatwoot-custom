class KanbanCards::PurgeDeletedJob < ApplicationJob
  BATCH_SIZE = 100

  queue_as :scheduled_jobs

  def perform
    KanbanCard.purgeable.in_batches(of: BATCH_SIZE) do |cards|
      KanbanCards::PurgeService.new(cards.pluck(:id)).perform
    end
  end
end
