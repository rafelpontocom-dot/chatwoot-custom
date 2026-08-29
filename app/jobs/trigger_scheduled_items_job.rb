class TriggerScheduledItemsJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    # trigger the scheduled campaign jobs
    Campaign.where(campaign_type: :one_off,
                   campaign_status: :active).where(scheduled_at: 3.days.ago..Time.current).all.find_each(batch_size: 100) do |campaign|
      Campaigns::TriggerOneoffCampaignJob.perform_later(campaign)
    end

    # Job to reopen snoozed conversations
    Conversations::ReopenSnoozedConversationsJob.perform_later

    # Job to reopen snoozed notifications
    Notification::ReopenSnoozedNotificationsJob.perform_later

    # Job to auto-resolve conversations
    Account::ConversationsResolutionSchedulerJob.perform_later

    # Job to surface due internal sales follow-ups in the activity center
    KanbanCadences::ProcessDueJob.perform_later

    # Job to deliver due opt-in appointment reminders.
    KanbanAppointmentReminders::ProcessDueJob.perform_later

    # Job to schedule internal reminders before configured appointments
    KanbanBoards::ScheduleAppointmentRemindersJob.perform_later

    # Send opt-in birthday messages through the existing conversation channels.
    KanbanBirthdayAutomations::ProcessJob.perform_later

    # Trigger commercial automations for open opportunities with overdue next actions.
    KanbanAutomations::DispatchOverdueNextActionsJob.perform_later

    # Keep externally controlled manual charges aligned with their due date.
    Finance::MarkOverduePaymentsJob.perform_later

    # Expire individual form links and trigger only eligible commercial automations.
    Forms::ExpireInvitationsJob.perform_later

    # Detect configured commercial invitations that remain unopened after sending.
    Forms::DetectAbandonedInvitationsJob.perform_later

    # Job to sync whatsapp templates
    Channels::Whatsapp::TemplatesSyncSchedulerJob.perform_later
  end
end

TriggerScheduledItemsJob.prepend_mod_with('TriggerScheduledItemsJob')
