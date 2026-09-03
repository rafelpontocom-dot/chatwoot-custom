class Internal::TriggerHourlyScheduledItemsJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    # Marketing: token do Meta expirando e formularios que o anunciante mexeu.
    Marketing::FlagExpiringConnectionsJob.perform_later
    Marketing::SyncLeadFormsSchedulerJob.perform_later
  end
end

Internal::TriggerHourlyScheduledItemsJob.prepend_mod_with('Internal::TriggerHourlyScheduledItemsJob')
