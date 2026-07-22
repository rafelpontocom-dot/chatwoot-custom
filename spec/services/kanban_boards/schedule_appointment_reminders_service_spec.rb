require 'rails_helper'

RSpec.describe KanbanBoards::ScheduleAppointmentRemindersService do
  let(:board) { create(:kanban_board, appointment_reminder_hours: 24) }
  let(:stage) { create(:kanban_stage, account: board.account, kanban_board: board) }
  let(:inbox) { create(:inbox, account: board.account) }

  it 'schedules an internal next action before an appointment' do
    card = create(
      :kanban_card,
      account: board.account,
      kanban_board: board,
      kanban_stage: stage,
      inbox: inbox,
      starts_at: 26.hours.from_now,
      next_action_type: nil,
      next_action_at: nil
    )

    described_class.new(board).call

    expect(card.reload).to have_attributes(
      next_action_type: 'Lembrete de agendamento',
      next_action_at: be_within(1.second).of(2.hours.from_now)
    )
    expect(card.next_action_note).to match(/agendamento/i)
  end

  it 'does not overwrite an existing next action' do
    card = create(
      :kanban_card,
      account: board.account,
      kanban_board: board,
      kanban_stage: stage,
      inbox: inbox,
      starts_at: 26.hours.from_now,
      next_action_type: 'Ligar para confirmar',
      next_action_at: 1.hour.from_now
    )

    described_class.new(board).call

    expect(card.reload).to have_attributes(
      next_action_type: 'Ligar para confirmar',
      next_action_at: be_within(1.second).of(1.hour.from_now)
    )
  end

  it 'does not schedule reminders for terminal or past appointments' do
    won_card = create(
      :kanban_card,
      account: board.account,
      kanban_board: board,
      kanban_stage: stage,
      inbox: inbox,
      starts_at: 26.hours.from_now,
      won_at: Time.current
    )
    past_card = create(
      :kanban_card,
      account: board.account,
      kanban_board: board,
      kanban_stage: stage,
      inbox: inbox,
      starts_at: 1.hour.ago
    )

    described_class.new(board).call

    expect(won_card.reload.next_action_at).to be_nil
    expect(past_card.reload.next_action_at).to be_nil
  end

  it 'does nothing when appointment reminders are disabled' do
    board.update!(appointment_reminder_hours: nil)
    card = create(
      :kanban_card,
      account: board.account,
      kanban_board: board,
      kanban_stage: stage,
      inbox: inbox,
      starts_at: 26.hours.from_now
    )

    expect { described_class.new(board).call }.not_to(change { card.reload.next_action_at })
  end
end
