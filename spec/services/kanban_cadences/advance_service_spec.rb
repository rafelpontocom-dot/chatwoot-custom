require 'rails_helper'

RSpec.describe KanbanCadences::AdvanceService do
  it 'sets the due step as the card next action and waits for completion' do
    board = create(:kanban_board)
    card = create(:kanban_card, account: board.account, kanban_board: board)
    cadence = create(
      :kanban_cadence,
      account: board.account,
      kanban_board: board,
      steps: [
        { delay_hours: 0, action_type: 'Ligar', note: 'Primeiro contato' },
        { delay_hours: 24, action_type: 'Retorno', note: 'Cobrar retorno' }
      ]
    )
    enrollment = create(
      :kanban_cadence_enrollment,
      account: board.account,
      kanban_board: board,
      kanban_card: card,
      kanban_cadence: cadence,
      next_run_at: 1.minute.ago
    )

    described_class.new(enrollment).call

    expect(enrollment.reload).to be_awaiting_completion
    expect(enrollment.current_step).to eq(0)
    expect(enrollment.next_run_at).to be_nil
    expect(card.reload.next_action_type).to eq('Ligar')
    expect(card.next_action_note).to eq('Primeiro contato')
  end

  it 'pauses the enrollment when the card is already closed' do
    board = create(:kanban_board)
    card = create(:kanban_card, account: board.account, kanban_board: board, won_at: Time.current)
    cadence = create(:kanban_cadence, account: board.account, kanban_board: board)
    enrollment = create(
      :kanban_cadence_enrollment,
      account: board.account,
      kanban_board: board,
      kanban_card: card,
      kanban_cadence: cadence,
      next_run_at: 1.minute.ago
    )

    described_class.new(enrollment).call

    expect(enrollment.reload).to be_paused
    expect(enrollment.paused_at).to be_present
  end
end
