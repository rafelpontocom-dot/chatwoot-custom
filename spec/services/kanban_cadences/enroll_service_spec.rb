require 'rails_helper'

RSpec.describe KanbanCadences::EnrollService do
  it 'schedules the first step without sending a customer message' do
    board = create(:kanban_board)
    card = create(:kanban_card, account: board.account, kanban_board: board)
    cadence = create(
      :kanban_cadence,
      account: board.account,
      kanban_board: board,
      steps: [{ delay_hours: 24, action_type: 'Ligar', note: 'Ligar para confirmar' }]
    )

    enrollment = described_class.new(card: card, cadence: cadence, user: create(:user, account: board.account)).call

    expect(enrollment).to be_active
    expect(enrollment.current_step).to eq(0)
    expect(enrollment.next_run_at).to be_within(1.minute).of(24.hours.from_now)
    expect(card.reload.next_action_at).to be_nil
  end

  it 'restarts a completed enrollment instead of creating a duplicate' do
    board = create(:kanban_board)
    card = create(:kanban_card, account: board.account, kanban_board: board)
    cadence = create(:kanban_cadence, account: board.account, kanban_board: board)
    existing = create(
      :kanban_cadence_enrollment,
      account: board.account,
      kanban_board: board,
      kanban_card: card,
      kanban_cadence: cadence,
      status: 'completed',
      completed_at: 1.hour.ago
    )

    enrollment = described_class.new(card: card, cadence: cadence, user: create(:user, account: board.account)).call

    expect(enrollment.id).to eq(existing.id)
    expect(enrollment).to be_active
    expect(enrollment.current_step).to eq(0)
  end
end
