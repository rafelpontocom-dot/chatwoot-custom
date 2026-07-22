require 'rails_helper'

RSpec.describe KanbanBoards::ScheduleAppointmentRemindersJob do
  it 'schedules reminders for active boards with the feature enabled' do
    board = create(:kanban_board, appointment_reminder_hours: 24)
    disabled_board = create(:kanban_board, appointment_reminder_hours: nil)

    expect(KanbanBoards::ScheduleAppointmentRemindersService).to receive(:new).with(board).and_call_original
    expect(KanbanBoards::ScheduleAppointmentRemindersService).not_to receive(:new).with(disabled_board)

    described_class.perform_now
  end
end
