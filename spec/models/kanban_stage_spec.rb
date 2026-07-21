require 'rails_helper'

RSpec.describe KanbanStage do
  it 'uses slate as the default color for new stages' do
    board = create(:kanban_board)

    stage = described_class.create!(
      account: board.account,
      kanban_board: board,
      name: 'New',
      position: 1
    )

    expect(stage.color).to eq('slate')
  end

  describe 'validations' do
    it 'accepts the commercial stage categories' do
      board = create(:kanban_board)

      stages = described_class::CATEGORIES.map do |category|
        build(:kanban_stage, account: board.account, kanban_board: board, category: category)
      end

      expect(stages).to all(be_valid)
    end

    it 'rejects an unknown commercial stage category' do
      stage = build(:kanban_stage, category: 'waiting')

      expect(stage).not_to be_valid
      expect(stage.errors[:category]).to be_present
    end

    it 'accepts a positive optional work in progress limit' do
      board = create(:kanban_board)
      stage_attributes = { account: board.account, kanban_board: board }

      expect(build(:kanban_stage, **stage_attributes, wip_limit: nil)).to be_valid
      expect(build(:kanban_stage, **stage_attributes, wip_limit: 10)).to be_valid
      expect(build(:kanban_stage, **stage_attributes, wip_limit: 0)).not_to be_valid
    end

    it 'prevents duplicate active names inside a board' do
      board = create(:kanban_board)
      create(:kanban_stage, account: board.account, kanban_board: board, name: 'New')

      stage = build(:kanban_stage, account: board.account, kanban_board: board, name: 'New')

      expect(stage).not_to be_valid
      expect(stage.errors[:name]).to be_present
    end

    it 'allows the same name when the previous stage is inactive' do
      board = create(:kanban_board)
      create(:kanban_stage, account: board.account, kanban_board: board, name: 'New', active: false)

      stage = build(:kanban_stage, account: board.account, kanban_board: board, name: 'New')

      expect(stage).to be_valid
    end

    it 'validates the board belongs to the same account' do
      board = create(:kanban_board)
      other_account = create(:account)

      stage = build(:kanban_stage, account: other_account, kanban_board: board)

      expect(stage).not_to be_valid
      expect(stage.errors[:account_id]).to be_present
    end
  end

  describe '.normalize_positions_for_board!' do
    it 'normalizes active stages inside the board by position, creation time, and id' do
      board = create(:kanban_board)
      later_stage = create(:kanban_stage, account: board.account, kanban_board: board, position: 2)
      first_duplicate = create(:kanban_stage, account: board.account, kanban_board: board, position: 1)
      second_duplicate = create(:kanban_stage, account: board.account, kanban_board: board, position: 1)

      described_class.normalize_positions_for_board!(board)

      expect(first_duplicate.reload.position).to eq(1)
      expect(second_duplicate.reload.position).to eq(2)
      expect(later_stage.reload.position).to eq(3)
    end

    it 'does not normalize inactive stages or stages from another board' do
      board = create(:kanban_board)
      other_board = create(:kanban_board, account: board.account)
      active_stage = create(:kanban_stage, account: board.account, kanban_board: board, position: 10)
      inactive_stage = create(:kanban_stage, account: board.account, kanban_board: board, active: false, position: 10)
      other_board_stage = create(:kanban_stage, account: board.account, kanban_board: other_board, position: 10)

      described_class.normalize_positions_for_board!(board)

      expect(active_stage.reload.position).to eq(1)
      expect(inactive_stage.reload.position).to eq(10)
      expect(other_board_stage.reload.position).to eq(10)
    end
  end
end
