class Forms::DetectAbandonedInvitationsJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Forms::DetectAbandonedInvitationsService.new.perform!
  end
end
