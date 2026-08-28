class Finance::MarkOverduePaymentsJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Finance::MarkOverduePaymentsService.new.perform!
  end
end
