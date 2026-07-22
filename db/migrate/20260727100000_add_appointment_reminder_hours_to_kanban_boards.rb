class AddAppointmentReminderHoursToKanbanBoards < ActiveRecord::Migration[7.1]
  def change
    add_column :kanban_boards, :appointment_reminder_hours, :integer
  end
end
