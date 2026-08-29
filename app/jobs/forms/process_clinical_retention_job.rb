class Forms::ProcessClinicalRetentionJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Forms::ClinicalRetentionService.new.perform!
  end
end
