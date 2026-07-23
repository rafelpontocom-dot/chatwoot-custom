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

  it 'waits for a customer response and stores the next node' do
    card = create(:kanban_card)
    rule = create(
      :kanban_automation_rule,
      account: card.account,
      kanban_board: card.kanban_board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger', data: {} },
          { id: 'reply', type: 'wait_for_response', data: { timeout_hours: 48 } },
          { id: 'end', type: 'end', data: {} }
        ],
        edges: [
          { source: 'trigger', target: 'reply' },
          { source: 'reply', target: 'end' }
        ]
      }
    )
    execution = create(:kanban_automation_execution, account: card.account, kanban_automation_rule: rule, kanban_card: card)
    now = Time.zone.parse('2026-07-23 10:00:00')

    result = described_class.new(execution: execution, rule: rule, card: card, now: now).perform!

    expect(result).to include(status: :waiting, scheduled_at: now + 48.hours)
    expect(result[:workflow_state]).to include('next_node_id' => 'end', 'waiting_for' => 'customer_message')
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

  it 'waits at a message node when a delivery policy defers it' do
    card = create(:kanban_card)
    rule = create(
      :kanban_automation_rule,
      account: card.account,
      kanban_board: card.kanban_board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger', data: {} },
          { id: 'message', type: 'send_message', data: { channel: 'whatsapp', opt_in_attribute_key: 'marketing_messages_opt_in', content: 'Olá' } },
          { id: 'end', type: 'end', data: {} }
        ],
        edges: [
          { source: 'trigger', target: 'message' },
          { source: 'message', target: 'end' }
        ]
      }
    )
    execution = create(:kanban_automation_execution, account: card.account, kanban_automation_rule: rule)
    scheduled_at = 2.hours.from_now
    message_service = instance_double(KanbanAutomations::WorkflowMessageService)
    allow(KanbanAutomations::WorkflowMessageService).to receive(:new).and_return(message_service)
    allow(message_service).to receive(:perform!).and_return(
      { 'action_name' => 'send_message', 'status' => 'waiting', 'reason' => 'quiet_hours', 'scheduled_at' => scheduled_at.iso8601 }
    )

    result = described_class.new(execution: execution, rule: rule, card: card).perform!

    expect(result.fetch(:status)).to eq(:waiting)
    expect(result.fetch(:scheduled_at)).to be_within(1.second).of(scheduled_at)
    expect(result[:workflow_state]).to include('next_node_id' => 'message')
  end

  it 'waits for a customer response before continuing the flow' do
    card = create(:kanban_card)
    rule = create(
      :kanban_automation_rule,
      account: card.account,
      kanban_board: card.kanban_board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger', data: {} },
          { id: 'response', type: 'wait_for_response', data: { timeout_hours: 12 } },
          { id: 'end', type: 'end', data: {} }
        ],
        edges: [
          { source: 'trigger', target: 'response' },
          { source: 'response', target: 'end' }
        ]
      }
    )
    execution = create(:kanban_automation_execution, account: card.account, kanban_automation_rule: rule, kanban_card: card)
    now = Time.zone.parse('2026-08-01 12:00:00')

    result = described_class.new(execution: execution, rule: rule, card: card, now: now).perform!

    expect(result).to include(status: :waiting, scheduled_at: now + 12.hours)
    expect(result[:workflow_state]).to include('next_node_id' => 'end', 'waiting_for' => 'customer_message')
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

  it 'enrolls the opportunity in a board cadence from an action node' do
    board = create(:kanban_board)
    card = create(:kanban_card, account: board.account, kanban_board: board)
    cadence = create(:kanban_cadence, account: board.account, kanban_board: board)
    rule = create(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger', data: {} },
          {
            id: 'cadence',
            type: 'action',
            data: { action_name: 'enroll_cadence', action_params: { cadence_id: cadence.id } }
          },
          { id: 'end', type: 'end', data: {} }
        ],
        edges: [
          { source: 'trigger', target: 'cadence' },
          { source: 'cadence', target: 'end' }
        ]
      }
    )
    execution = create(:kanban_automation_execution, account: board.account, kanban_automation_rule: rule)

    result = described_class.new(execution: execution, rule: rule, card: card).perform!

    expect(result[:status]).to eq(:succeeded)
    expect(card.kanban_cadence_enrollments.find_by(kanban_cadence: cadence)).to be_active
    expect(result[:action_results]).to include(hash_including('node_id' => 'cadence', 'action_name' => 'enroll_cadence'))
  end

  it 'adds a label and an internal note through action nodes' do
    conversation = create(:conversation)
    card = create(:kanban_card, :conversation_origin, conversation: conversation)
    rule = create(
      :kanban_automation_rule,
      account: card.account,
      kanban_board: card.kanban_board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger', data: {} },
          { id: 'label', type: 'action', data: { action_name: 'add_label', action_params: { label: 'prioridade' } } },
          { id: 'note', type: 'action', data: { action_name: 'add_note', action_params: { content: 'Revisar proposta comercial.' } } },
          { id: 'end', type: 'end', data: {} }
        ],
        edges: [
          { source: 'trigger', target: 'label' },
          { source: 'label', target: 'note' },
          { source: 'note', target: 'end' }
        ]
      }
    )
    execution = create(:kanban_automation_execution, account: card.account, kanban_automation_rule: rule, kanban_card: card)

    expect do
      result = described_class.new(execution: execution, rule: rule, card: card).perform!
      expect(result[:status]).to eq(:succeeded)
    end.to change { conversation.messages.where(private: true).count }.by(1)

    expect(card.reload.label_list).to include('prioridade')
    expect(conversation.messages.where(private: true).last.content).to eq('Revisar proposta comercial.')
  end

  it 'delivers a signed webhook node without exposing its secret in the execution log' do
    board = create(:kanban_board)
    card = create(:kanban_card, account: board.account, kanban_board: board)
    connection = create(
      :kanban_automation_connection,
      account: board.account,
      kanban_board: board,
      webhook_url: 'https://automacao.example.test/hooks/lead'
    )
    rule = create(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger', data: {} },
          { id: 'webhook', type: 'webhook', data: { connection_id: connection.id } },
          { id: 'end', type: 'end', data: {} }
        ],
        edges: [
          { source: 'trigger', target: 'webhook' },
          { source: 'webhook', target: 'end' }
        ]
      }
    )
    execution = create(:kanban_automation_execution, account: board.account, kanban_automation_rule: rule, kanban_card: card)
    delivery = instance_double(KanbanAutomations::WebhookDeliveryService)
    allow(KanbanAutomations::WebhookDeliveryService).to receive(:new).and_return(delivery)
    allow(delivery).to receive(:perform!).and_return(
      { 'action_name' => 'webhook', 'status' => 'succeeded', 'connection_id' => connection.id, 'status_code' => 202 }
    )

    result = described_class.new(execution: execution, rule: rule, card: card).perform!

    expect(result[:status]).to eq(:succeeded)
    expect(result[:action_results]).to include(hash_including('node_id' => 'webhook', 'status_code' => 202))
    expect(result.to_json).not_to include(connection.secret)
  end
end
