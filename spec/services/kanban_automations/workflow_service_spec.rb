require 'rails_helper'

RSpec.describe KanbanAutomations::WorkflowService do
  it 'pauses at a delay node and stores the next node to execute' do
    card = create(:kanban_card)
    rule = create(
      :kanban_automation_rule,
      account: card.account,
      kanban_board: card.kanban_board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger', data: {} },
          { id: 'wait', type: 'delay', data: { delay_hours: 24 } },
          { id: 'end', type: 'end', data: {} }
        ],
        edges: [
          { source: 'trigger', target: 'wait' },
          { source: 'wait', target: 'end' }
        ]
      }
    )
    execution = create(:kanban_automation_execution, account: card.account, kanban_automation_rule: rule)
    now = Time.zone.parse('2026-07-31 12:00:00')

    result = described_class.new(execution: execution, rule: rule, card: card, now: now).perform!

    expect(result).to include(status: :waiting, scheduled_at: now + 24.hours)
    expect(result[:workflow_state]).to include('next_node_id' => 'end')
  end

  it 'executes an internal action node before completing the workflow' do
    board = create(:kanban_board, custom_field_definitions: [{ key: 'origem', label: 'Origem', field_type: 'text' }])
    card = create(:kanban_card, account: board.account, kanban_board: board, custom_field_values: {})
    rule = create(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger', data: {} },
          { id: 'field', type: 'action', data: { action_name: 'set_field', action_params: { field_key: 'origem', value: 'Automação visual' } } },
          { id: 'end', type: 'end', data: {} }
        ],
        edges: [
          { source: 'trigger', target: 'field' },
          { source: 'field', target: 'end' }
        ]
      }
    )
    execution = create(:kanban_automation_execution, account: board.account, kanban_automation_rule: rule)

    result = described_class.new(execution: execution, rule: rule, card: card).perform!

    expect(result[:status]).to eq(:succeeded)
    expect(card.reload.custom_field_values).to include('origem' => 'Automação visual')
  end

  it 'records a skipped message node when no compatible conversation exists' do
    card = create(:kanban_card)
    rule = create(
      :kanban_automation_rule,
      account: card.account,
      kanban_board: card.kanban_board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger', data: {} },
          { id: 'message', type: 'send_message',
            data: { channel: 'whatsapp', opt_in_attribute_key: 'marketing_messages_opt_in', content: 'Olá, {{contact_name}}!' } },
          { id: 'end', type: 'end', data: {} }
        ],
        edges: [
          { source: 'trigger', target: 'message' },
          { source: 'message', target: 'end' }
        ]
      }
    )
    execution = create(:kanban_automation_execution, account: card.account, kanban_automation_rule: rule)

    result = described_class.new(execution: execution, rule: rule, card: card).perform!

    expect(result[:status]).to eq(:succeeded)
    expect(result[:action_results]).to include(hash_including('node_id' => 'message', 'status' => 'skipped',
                                                              'reason' => 'no_compatible_conversation'))
  end

  # rubocop:disable RSpec/ExampleLength
  it 'follows the yes branch of a condition node' do
    board = create(
      :kanban_board,
      custom_field_definitions: [
        { key: 'origem', label: 'Origem', field_type: 'text' },
        { key: 'resultado', label: 'Resultado', field_type: 'text' }
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
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger', data: {} },
          {
            id: 'condition',
            type: 'condition',
            data: { field_key: 'origem', operator: 'equals', value: 'Mídia Paga' }
          },
          {
            id: 'yes-action',
            type: 'action',
            data: { action_name: 'set_field', action_params: { field_key: 'resultado', value: 'Qualificado' } }
          },
          {
            id: 'no-action',
            type: 'action',
            data: { action_name: 'set_field', action_params: { field_key: 'resultado', value: 'Revisar' } }
          },
          { id: 'end', type: 'end', data: {} }
        ],
        edges: [
          { source: 'trigger', target: 'condition' },
          { source: 'condition', sourceHandle: 'yes', target: 'yes-action' },
          { source: 'condition', sourceHandle: 'no', target: 'no-action' },
          { source: 'yes-action', target: 'end' },
          { source: 'no-action', target: 'end' }
        ]
      }
    )
    execution = create(:kanban_automation_execution, account: board.account, kanban_automation_rule: rule)

    result = described_class.new(execution: execution, rule: rule, card: card).perform!

    expect(result[:status]).to eq(:succeeded)
    expect(card.reload.custom_field_values).to include('resultado' => 'Qualificado')
    expect(result[:action_results]).to include(hash_including('node_id' => 'condition', 'branch' => 'yes'))
  end
  # rubocop:enable RSpec/ExampleLength

  it 'waits until a datetime field minus the configured offset' do
    board = create(
      :kanban_board,
      custom_field_definitions: [{ key: 'data_consulta', label: 'Data da consulta', field_type: 'datetime' }]
    )
    appointment_at = Time.zone.parse('2026-08-10 15:00:00')
    card = create(
      :kanban_card,
      account: board.account,
      kanban_board: board,
      custom_field_values: { data_consulta: appointment_at.iso8601 }
    )
    rule = create(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger', data: {} },
          { id: 'appointment', type: 'wait_until_field', data: { field_key: 'data_consulta', offset_hours: -24 } },
          { id: 'end', type: 'end', data: {} }
        ],
        edges: [
          { source: 'trigger', target: 'appointment' },
          { source: 'appointment', target: 'end' }
        ]
      }
    )
    execution = create(:kanban_automation_execution, account: board.account, kanban_automation_rule: rule)
    now = Time.zone.parse('2026-08-01 12:00:00')

    result = described_class.new(execution: execution, rule: rule, card: card, now: now).perform!

    expect(result).to include(status: :waiting, scheduled_at: appointment_at - 24.hours)
    expect(result[:workflow_state]).to include('next_node_id' => 'end')
  end
end
