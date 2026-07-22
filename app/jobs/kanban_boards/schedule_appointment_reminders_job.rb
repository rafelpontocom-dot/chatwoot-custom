class KanbanBoards::ScheduleAppointmentRemindersJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    KanbanBoard.active.where.not(appointment_reminder_hours: nil).find_each do |board|
      KanbanBoards::ScheduleAppointmentRemindersService.new(board).call
    end
  end
end
