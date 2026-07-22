require 'rails_helper'

RSpec.describe KanbanCadences::EnrollOnStageEntryService do
  it 'enrolls cards in cadences configured for the destination stage' do
    board = create(:kanban_board)
    stage = create(:kanban_stage, account: board.account, kanban_board: board)
    card = create(:kanban_card, account: board.account, kanban_board: board, kanban_stage: stage)
    cadence = create(:kanban_cadence, account: board.account, kanban_board: board,
                                      trigger_type: 'stage_entered', trigger_stage_id: stage.id)

    enrollment = described_class.new(card: card, stage: stage).call

    expect(enrollment).to be_present
    expect(enrollment.kanban_cadence).to eq(cadence)
  end

  it 'does not create a duplicate enrollment when the event is retried' do
    board = create(:kanban_board)
    stage = create(:kanban_stage, account: board.account, kanban_board: board)
    card = create(:kanban_card, account: board.account, kanban_board: board, kanban_stage: stage)
    create(:kanban_cadence, account: board.account, kanban_board: board,
                            trigger_type: 'stage_entered', trigger_stage_id: stage.id)

    service = described_class.new(card: card, stage: stage)
    service.call

    expect { service.call }.not_to change(KanbanCadenceEnrollment, :count)
  end
end
