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

  it 'skips unavailable owners when the round-robin policy requires online agents' do
    board = create(:kanban_board)
    online_owner = create(:user, account: board.account)
    offline_owner = create(:user, account: board.account)
    card = create(:kanban_card, account: board.account, kanban_board: board)
    rule = create(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      actions: [
        {
          action_name: 'assign_round_robin',
          action_params: {
            owner_ids: [offline_owner.id, online_owner.id],
            availability_policy: 'online_only'
          }
        }
      ]
    )
    allow(OnlineStatusTracker).to receive(:get_available_users).with(board.account.id).and_return(
      offline_owner.id.to_s => 'offline', online_owner.id.to_s => 'online'
    )

    result = described_class.new(rule: rule, card: card).perform!

    expect(card.reload.owner).to eq(online_owner)
    expect(result).to include(hash_including('action_name' => 'assign_round_robin', 'owner_id' => online_owner.id))
  end

  it 'does not assign an owner when no configured owner is available' do
    board = create(:kanban_board)
    owner = create(:user, account: board.account)
    card = create(:kanban_card, account: board.account, kanban_board: board)
    rule = create(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      actions: [
        {
          action_name: 'assign_round_robin',
          action_params: { owner_ids: [owner.id], availability_policy: 'online_only' }
        }
      ]
    )
    allow(OnlineStatusTracker).to receive(:get_available_users).with(board.account.id).and_return(owner.id.to_s => 'offline')

    result = described_class.new(rule: rule, card: card).perform!

    expect(card.reload.owner).to be_nil
    expect(result).to include(hash_including('action_name' => 'assign_round_robin', 'status' => 'skipped', 'reason' => 'no_available_owner'))
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

  it 'updates an explicitly configured contact attribute' do
    card = create(:kanban_card)
    rule = create(
      :kanban_automation_rule,
      account: card.account,
      kanban_board: card.kanban_board,
      actions: [
        {
          action_name: 'update_contact',
          action_params: { attribute_key: 'marketing_messages_opt_in', value: true }
        }
      ]
    )

    result = described_class.new(rule: rule, card: card).perform!

    expect(card.contact.reload.custom_attributes).to include('marketing_messages_opt_in' => true)
    expect(result).to include(hash_including('action_name' => 'update_contact', 'attribute_key' => 'marketing_messages_opt_in'))
  end

  it 'normalizes known contact attribute values before storing them' do
    card = create(:kanban_card)
    rule = create(
      :kanban_automation_rule,
      account: card.account,
      kanban_board: card.kanban_board,
      actions: [
        {
          action_name: 'update_contact',
          action_params: { attribute_key: 'marketing_messages_opt_in', value: 'false' }
        },
        {
          action_name: 'update_contact',
          action_params: { attribute_key: 'date_of_birth', value: '1990-02-03' }
        }
      ]
    )

    described_class.new(rule: rule, card: card).perform!

    expect(card.contact.reload.custom_attributes).to include(
      'marketing_messages_opt_in' => false,
      'date_of_birth' => '1990-02-03'
    )
  end

  it 'clears an existing configured opportunity field' do
    board = create(
      :kanban_board,
      custom_field_definitions: [
        { key: 'origem', label: 'Origem', field_type: 'text' },
        { key: 'manter', label: 'Manter', field_type: 'text' }
      ]
    )
    card = create(
      :kanban_card,
      account: board.account,
      kanban_board: board,
      custom_field_values: { origem: 'Mídia paga', manter: 'sim' }
    )
    rule = create(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      actions: [
        { action_name: 'clear_field', action_params: { field_key: 'origem' } }
      ]
    )

    result = described_class.new(rule: rule, card: card).perform!

    expect(card.reload.custom_field_values).to eq('manter' => 'sim')
    expect(result).to include(
      hash_including('action_name' => 'clear_field', 'field_key' => 'origem')
    )
  end

  it 'completes the current next action and preserves its history' do
    card = create(
      :kanban_card,
      next_action_type: 'Enviar proposta',
      next_action_at: 1.hour.from_now,
      next_action_note: 'Incluir condições comerciais'
    )
    rule = create(
      :kanban_automation_rule,
      account: card.account,
      kanban_board: card.kanban_board,
      actions: [
        {
          action_name: 'complete_next_action',
          action_params: { completion_note: 'Proposta aprovada durante a ligação' }
        }
      ]
    )

    result = described_class.new(rule: rule, card: card).perform!

    expect(card.reload.next_action_completed_at).to be_present
    expect(card.next_action_history.last).to include(
      'type' => 'Enviar proposta',
      'completion_note' => 'Proposta aprovada durante a ligação'
    )
    expect(result).to include(hash_including('action_name' => 'complete_next_action', 'status' => 'succeeded'))
  end

  it 'schedules the next commercial action after completing the current one' do
    card = create(
      :kanban_card,
      next_action_type: 'Enviar proposta',
      next_action_at: 1.hour.from_now,
      next_action_note: 'Incluir condições comerciais'
    )
    next_action_at = 2.days.from_now.change(usec: 0)
    rule = create(
      :kanban_automation_rule,
      account: card.account,
      kanban_board: card.kanban_board,
      actions: [
        {
          action_name: 'complete_next_action',
          action_params: {
            completion_note: 'Proposta enviada',
            next_action_type: 'Ligar para confirmar',
            next_action_at: next_action_at.iso8601,
            next_action_note: 'Confirmar recebimento'
          }
        }
      ]
    )

    described_class.new(rule: rule, card: card).perform!

    expect(card.reload).to have_attributes(
      next_action_type: 'Ligar para confirmar',
      next_action_at: next_action_at,
      next_action_note: 'Confirmar recebimento',
      next_action_completed_at: nil
    )
    expect(card.next_action_history.last).to include(
      'type' => 'Enviar proposta',
      'completion_note' => 'Proposta enviada'
    )
  end

  it 'does not complete the current action when the follow-up date is invalid' do
    card = create(
      :kanban_card,
      next_action_type: 'Enviar proposta',
      next_action_at: 1.hour.from_now,
      next_action_note: 'Incluir condições comerciais'
    )
    rule = create(
      :kanban_automation_rule,
      account: card.account,
      kanban_board: card.kanban_board,
      actions: [
        {
          action_name: 'complete_next_action',
          action_params: {
            next_action_type: 'Ligar para confirmar',
            next_action_at: 'data inválida'
          }
        }
      ]
    )

    expect do
      described_class.new(rule: rule, card: card).perform!
    end.to raise_error(ArgumentError, 'next_action_at is invalid')

    expect(card.reload.next_action_completed_at).to be_nil
    expect(card.next_action_history).to be_empty
  end

  it 'marks an opportunity as won or lost using configured sales data' do
    board = create(:kanban_board, lost_reason_options: ['Preço', 'Sem resposta'])
    owner = create(:user, account: board.account)
    card = create(:kanban_card, account: board.account, kanban_board: board, owner: owner)
    rule = create(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      actions: [{ action_name: 'mark_won', action_params: {} }]
    )

    described_class.new(rule: rule, card: card).perform!

    expect(card.reload).to have_attributes(won_at: be_present, lost_at: nil, closed_by: owner)

    rule.update!(actions: [{ action_name: 'mark_lost', action_params: { lost_reason: 'Preço' } }])
    described_class.new(rule: rule, card: card).perform!

    expect(card.reload).to have_attributes(won_at: nil, lost_at: be_present, lost_reason: 'Preço', closed_by: owner)
  end

  it 'does not close an opportunity with fields required in its current stage missing' do
    board = create(
      :kanban_board,
      custom_field_definitions: [
        { key: 'cpf', label: 'CPF', field_type: 'text', required_stage_ids: [] }
      ]
    )
    stage = create(:kanban_stage, account: board.account, kanban_board: board)
    card = create(:kanban_card, account: board.account, kanban_board: board, kanban_stage: stage)
    board.update!(
      custom_field_definitions: [
        { key: 'cpf', label: 'CPF', field_type: 'text', required_stage_ids: [stage.id] }
      ]
    )
    rule = create(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      actions: [{ action_name: 'mark_won', action_params: {} }]
    )

    expect { described_class.new(rule: rule, card: card).perform! }.to raise_error(ActiveRecord::RecordInvalid)
    expect(card.reload.won_at).to be_nil
  end
end
