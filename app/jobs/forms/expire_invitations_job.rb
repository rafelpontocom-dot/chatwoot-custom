class Forms::ExpireInvitationsJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Forms::ExpireInvitationsService.new.perform!
  end
end
