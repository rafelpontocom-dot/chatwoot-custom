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

  it 'adds and removes opportunity labels' do
    card = create(:kanban_card)
    rule = create(
      :kanban_automation_rule,
      account: card.account,
      kanban_board: card.kanban_board,
      actions: [{ action_name: 'add_label', action_params: { label: 'prioridade-alta' } }]
    )

    described_class.new(rule: rule, card: card).perform!

    expect(card.reload.label_list).to include('prioridade-alta')

    rule.update!(actions: [{ action_name: 'remove_label', action_params: { label: 'prioridade-alta' } }])
    described_class.new(rule: rule, card: card).perform!

    expect(card.reload.label_list).not_to include('prioridade-alta')
  end

  it 'increments a numeric custom field for each follow-up attempt' do
    board = create(
      :kanban_board,
      custom_field_definitions: [
        { key: 'follow_up_attempts', label: 'Tentativas de follow-up', field_type: 'integer' }
      ]
    )
    card = create(
      :kanban_card,
      account: board.account,
      kanban_board: board,
      custom_field_values: { follow_up_attempts: 2 }
    )
    rule = create(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      actions: [
        { action_name: 'increment_field', action_params: { field_key: 'follow_up_attempts', amount: 1 } }
      ]
    )

    result = described_class.new(rule: rule, card: card).perform!

    expect(card.reload.custom_field_values).to include('follow_up_attempts' => 3)
    expect(result).to include(hash_including('action_name' => 'increment_field', 'amount' => 1))
  end

  it 'assigns owners in the configured round-robin order' do
    board = create(:kanban_board)
    first_owner = create(:user, account: board.account)
    second_owner = create(:user, account: board.account)
    first_card = create(:kanban_card, account: board.account, kanban_board: board)
    second_card = create(:kanban_card, account: board.account, kanban_board: board)
    rule = create(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      actions: [
        { action_name: 'assign_round_robin', action_params: { owner_ids: [first_owner.id, second_owner.id] } }
      ]
    )

    first_result = described_class.new(rule: rule, card: first_card).perform!
    second_result = described_class.new(rule: rule, card: second_card).perform!

    expect(first_card.reload.owner).to eq(first_owner)
    expect(second_card.reload.owner).to eq(second_owner)
    expect(first_result).to include(hash_including('action_name' => 'assign_round_robin', 'owner_id' => first_owner.id))
    expect(second_result).to include(hash_including('action_name' => 'assign_round_robin', 'owner_id' => second_owner.id))
  end

  it 'records an internal note only in the linked conversation' do
    conversation = create(:conversation)
    card = create(:kanban_card, :conversation_origin, conversation: conversation)
    rule = create(
      :kanban_automation_rule,
      account: card.account,
      kanban_board: card.kanban_board,
      actions: [{ action_name: 'add_note', action_params: { content: 'Revisar proposta antes da ligação.' } }]
    )

    expect do
      described_class.new(rule: rule, card: card).perform!
    end.to change(conversation.messages, :count).by(1)

    note = conversation.messages.order(:id).last
    expect(note).to have_attributes(content: 'Revisar proposta antes da ligação.', private: true)
  end
end
