require 'rails_helper'

RSpec.describe KanbanSavedFilter do
  it 'stores a personal board filter' do
    board = create(:kanban_board)
    user = create(:user, account: board.account)
    filter = described_class.new(
      account: board.account,
      kanban_board: board,
      user: user,
      name: 'Minhas oportunidades atrasadas',
      filters: { next_action: 'overdue', sort: 'next_action_asc' }
    )

    expect(filter).to be_valid
  end

  it 'rejects a board or user from another account' do
    board = create(:kanban_board)
    filter = described_class.new(
      account: create(:account),
      kanban_board: board,
      user: create(:user),
      name: 'Inválido',
      filters: {}
    )

    expect(filter).not_to be_valid
    expect(filter.errors[:account_id]).to be_present
  end
end
