require 'rails_helper'

RSpec.describe KanbanCadences::ProcessDueJob do
  it 'processes due enrollments in bounded batches' do
    relation = instance_double(ActiveRecord::Relation)

    allow(KanbanCadenceEnrollment).to receive(:due).and_return(relation)
    allow(relation).to receive(:includes).with(:kanban_card, :kanban_cadence).and_return(relation)
    expect(relation).to receive(:find_each).with(batch_size: described_class::BATCH_SIZE)

    described_class.perform_now
  end

  it 'processes only due active enrollments' do
    board = create(:kanban_board)
    card = create(:kanban_card, account: board.account, kanban_board: board)
    cadence = create(:kanban_cadence, account: board.account, kanban_board: board)
    due = create(
      :kanban_cadence_enrollment,
      account: board.account,
      kanban_board: board,
      kanban_card: card,
      kanban_cadence: cadence,
      next_run_at: 1.minute.ago
    )
    future_card = create(:kanban_card, account: board.account, kanban_board: board)
    future = create(
      :kanban_cadence_enrollment,
      account: board.account,
      kanban_board: board,
      kanban_card: future_card,
      kanban_cadence: cadence,
      next_run_at: 1.hour.from_now
    )

    described_class.perform_now

    expect(due.reload).to be_awaiting_completion
    expect(future.reload).to be_active
  end
end
