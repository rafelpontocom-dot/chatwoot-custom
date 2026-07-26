class KanbanAppointmentReminders::ProcessDueJob < ApplicationJob
  BATCH_SIZE = 100

  queue_as :scheduled_jobs

  def perform
    KanbanAppointmentReminderDelivery.due.includes(:kanban_appointment_reminder_rule, :kanban_card).find_each(batch_size: BATCH_SIZE) do |delivery|
      KanbanAppointmentReminders::DeliverService.new(delivery).call
    rescue StandardError => e
      Rails.logger.error("Kanban appointment reminder #{delivery.id} failed: #{e.message}")
    end
  end
end
