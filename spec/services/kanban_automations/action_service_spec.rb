require 'rails_helper'

RSpec.describe KanbanAutomations::ActionService do
  it 'applies internal actions without creating a message' do
    board = create(:kanban_board, custom_field_definitions: [{ key: 'origem', label: 'Origem', field_type: 'text' }])
    target_stage = create(:kanban_stage, account: board.account, kanban_board: board)
    owner = create(:user, account: board.account)
    card = create(:kanban_card, account: board.account, kanban_board: board, custom_field_values: {})
    rule = create(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      actions: [
        { action_name: 'move_stage', action_params: { stage_id: target_stage.id } },
        { action_name: 'assign_owner', action_params: { owner_id: owner.id } },
        { action_name: 'set_field', action_params: { field_key: 'origem', value: 'Automação' } }
      ]
    )

    expect do
      described_class.new(rule: rule, card: card).perform!
    end.not_to change(Message, :count)

    expect(card.reload).to have_attributes(kanban_stage_id: target_stage.id, owner_id: owner.id)
    expect(card.custom_field_values['origem']).to eq('Automação')
  end
end
