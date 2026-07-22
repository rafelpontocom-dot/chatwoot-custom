require 'rails_helper'

RSpec.describe KanbanCadenceEnrollment do
  it 'requires the card, cadence and account to share the same account' do
    account = create(:account)
    other_account = create(:account)
    board = create(:kanban_board, account: account)
    card = create(:kanban_card, account: account, kanban_board: board)
    cadence = create(:kanban_cadence, account: other_account, kanban_board: create(:kanban_board, account: other_account))

    enrollment = build(:kanban_cadence_enrollment, account: account, kanban_board: board, kanban_card: card, kanban_cadence: cadence)

    expect(enrollment).not_to be_valid
    expect(enrollment.errors[:kanban_cadence]).to be_present
  end
end
