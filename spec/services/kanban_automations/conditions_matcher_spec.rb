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

  it 'treats an exists condition without a value as a populated field' do
    card = create(:kanban_card, subject: 'Orçamento')
    rule = create(
      :kanban_automation_rule,
      account: card.account,
      kanban_board: card.kanban_board,
      conditions: { fields: [{ field_key: 'system_subject', operator: 'exists', value: '' }] }
    )

    expect(described_class.new(rule: rule, card: card).matches?).to be(true)
  end

  it 'matches a custom-field trigger only when the selected field changed' do
    board = create(
      :kanban_board,
      custom_field_definitions: [
        { key: 'origem', label: 'Origem', field_type: 'select', options: ['Orgânico', 'Mídia Paga'] },
        { key: 'campanha', label: 'Campanha', field_type: 'text' }
      ]
    )
    card = create(
      :kanban_card,
      account: board.account,
      kanban_board: board,
      custom_field_values: { origem: 'Mídia Paga', campanha: 'Inverno' }
    )
    rule = create(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      event_name: Events::Types::KANBAN_CARD_CUSTOM_FIELDS_CHANGED,
      conditions: { changed_field_keys: ['origem'] }
    )
    event = create(
      :kanban_card_event,
      account: board.account,
      kanban_board: board,
      kanban_card: card,
      event_type: 'custom_fields_changed',
      change_set: {
        custom_field_values: [
          { origem: 'Orgânico', campanha: 'Inverno' },
          { origem: 'Mídia Paga', campanha: 'Inverno' }
        ]
      }
    )

    expect(described_class.new(rule: rule, card: card, event: event).matches?).to be(true)
  end

  it 'does not match a selected custom-field trigger when another field changed' do
    board = create(
      :kanban_board,
      custom_field_definitions: [
        { key: 'origem', label: 'Origem', field_type: 'select', options: ['Orgânico', 'Mídia Paga'] },
        { key: 'campanha', label: 'Campanha', field_type: 'text' }
      ]
    )
    card = create(
      :kanban_card,
      account: board.account,
      kanban_board: board,
      custom_field_values: { origem: 'Mídia Paga', campanha: 'Inverno' }
    )
    rule = create(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      event_name: Events::Types::KANBAN_CARD_CUSTOM_FIELDS_CHANGED,
      conditions: { changed_field_keys: ['origem'] }
    )
    event = create(
      :kanban_card_event,
      account: board.account,
      kanban_board: board,
      kanban_card: card,
      event_type: 'custom_fields_changed',
      change_set: {
        custom_field_values: [
          { origem: 'Mídia Paga', campanha: 'Outono' },
          { origem: 'Mídia Paga', campanha: 'Inverno' }
        ]
      }
    )

    expect(described_class.new(rule: rule, card: card, event: event).matches?).to be(false)
  end

  it 'matches a selected choice field trigger only when it changes to the selected option' do
    board = create(
      :kanban_board,
      custom_field_definitions: [
        { key: 'origem', label: 'Origem', field_type: 'select', options: ['Orgânico', 'Mídia Paga'] }
      ]
    )
    card = create(
      :kanban_card,
      account: board.account,
      kanban_board: board,
      custom_field_values: { origem: 'Mídia Paga' }
    )
    rule = create(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      event_name: Events::Types::KANBAN_CARD_FIELDS_CHANGED,
      conditions: {
        changed_field_keys: ['origem'],
        fields: [{ field_key: 'origem', operator: 'equals', value: 'Mídia Paga' }]
      }
    )
    event = create(
      :kanban_card_event,
      account: board.account,
      kanban_board: board,
      kanban_card: card,
      event_type: 'custom_fields_changed',
      change_set: { custom_field_values: [{ origem: 'Orgânico' }, { origem: 'Mídia Paga' }] }
    )

    expect(described_class.new(rule: rule, card: card, event: event).matches?).to be(true)
  end

  it 'matches a selected choice field trigger against its previous value when requested' do
    board = create(
      :kanban_board,
      custom_field_definitions: [
        { key: 'origem', label: 'Origem', field_type: 'select', options: ['Orgânico', 'Mídia Paga'] }
      ]
    )
    card = create(
      :kanban_card,
      account: board.account,
      kanban_board: board,
      custom_field_values: { origem: 'Mídia Paga' }
    )
    rule = create(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      event_name: Events::Types::KANBAN_CARD_FIELDS_CHANGED,
      conditions: {
        changed_field_keys: ['origem'],
        fields: [{ field_key: 'origem', operator: 'equals', value: 'Orgânico', value_source: 'previous' }]
      }
    )
    event = create(
      :kanban_card_event,
      account: board.account,
      kanban_board: board,
      kanban_card: card,
      event_type: 'custom_fields_changed',
      change_set: { custom_field_values: [{ origem: 'Orgânico' }, { origem: 'Mídia Paga' }] }
    )

    expect(described_class.new(rule: rule, card: card, event: event).matches?).to be(true)
  end

  it 'matches a selected native field in the any-field trigger' do
    card = create(:kanban_card, amount_cents: 150_000)
    rule = create(
      :kanban_automation_rule,
      account: card.account,
      kanban_board: card.kanban_board,
      event_name: Events::Types::KANBAN_CARD_FIELDS_CHANGED,
      conditions: { changed_field_keys: ['system_amount'] }
    )
    event = create(
      :kanban_card_event,
      account: card.account,
      kanban_board: card.kanban_board,
      kanban_card: card,
      event_type: 'amount_changed',
      change_set: { amount_cents: [100_000, 150_000] }
    )

    expect(described_class.new(rule: rule, card: card, event: event).matches?).to be(true)
  end

  it 'matches a customer reply trigger only when the reply contains the configured phrase' do
    card = create(:kanban_card)
    rule = create(
      :kanban_automation_rule,
      account: card.account,
      kanban_board: card.kanban_board,
      event_name: Events::Types::KANBAN_CARD_CUSTOMER_MESSAGE_RECEIVED,
      conditions: { customer_message_contains: 'consulta' }
    )

    expect(
      described_class.new(
        rule: rule,
        card: card,
        event_data: { customer_message_content: 'Como funciona a consulta?' }
      ).matches?
    ).to be(true)
    expect(
      described_class.new(
        rule: rule,
        card: card,
        event_data: { customer_message_content: 'Quero saber os valores.' }
      ).matches?
    ).to be(false)
  end
end
