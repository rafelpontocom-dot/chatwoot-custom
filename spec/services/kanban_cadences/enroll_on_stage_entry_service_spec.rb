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

  it 'enrolls the card in every active cadence configured for the destination stage' do
    board = create(:kanban_board)
    stage = create(:kanban_stage, account: board.account, kanban_board: board)
    card = create(:kanban_card, account: board.account, kanban_board: board, kanban_stage: stage)
    cadences = Array.new(2) do |index|
      create(
        :kanban_cadence,
        account: board.account,
        kanban_board: board,
        name: "Follow-up #{index + 1}",
        trigger_type: 'stage_entered',
        trigger_stage_id: stage.id
      )
    end

    described_class.new(card: card, stage: stage).call

    expect(card.kanban_cadence_enrollments.pluck(:kanban_cadence_id)).to match_array(cadences.map(&:id))
  end

  it 'returns the enrollment created by a concurrent worker' do
    board = create(:kanban_board)
    stage = create(:kanban_stage, account: board.account, kanban_board: board)
    card = create(:kanban_card, account: board.account, kanban_board: board, kanban_stage: stage)
    cadence = create(:kanban_cadence, account: board.account, kanban_board: board,
                                      trigger_type: 'stage_entered', trigger_stage_id: stage.id)
    concurrent_enrollment = nil

    allow(KanbanCadences::EnrollService).to receive(:new) do
      concurrent_enrollment = create(
        :kanban_cadence_enrollment,
        account: board.account,
        kanban_board: board,
        kanban_card: card,
        kanban_cadence: cadence
      )
      raise ActiveRecord::RecordNotUnique
    end

    enrollment = described_class.new(card: card, stage: stage).call

    expect(enrollment).to eq(concurrent_enrollment)
  end
end
