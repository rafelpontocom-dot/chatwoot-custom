require 'rails_helper'

RSpec.describe KanbanAutomations::ConditionsMatcher do
  it 'matches system and custom field conditions' do
    board = create(
      :kanban_board,
      custom_field_definitions: [{ key: 'origem', label: 'Origem', field_type: 'select', options: ['Mídia Paga'] }]
    )
    card = create(
      :kanban_card,
      kanban_board: board,
      account: board.account,
      amount_cents: 150_000,
      custom_field_values: { origem: 'Mídia Paga' }
    )
    rule = create(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      conditions: {
        stage_ids: [card.kanban_stage_id],
        fields: [
          { field_key: 'system_amount', operator: 'greater_or_equal', value: 1500 },
          { field_key: 'origem', operator: 'equals', value: 'Mídia Paga' }
        ]
      }
    )

    expect(described_class.new(rule: rule, card: card).matches?).to be(true)
  end

  it 'does not match a rule from another board' do
    card = create(:kanban_card)
    other_board = create(:kanban_board, account: card.account)
    rule = create(:kanban_automation_rule, account: card.account, kanban_board: other_board)

    expect(described_class.new(rule: rule, card: card).matches?).to be(false)
  end
end
