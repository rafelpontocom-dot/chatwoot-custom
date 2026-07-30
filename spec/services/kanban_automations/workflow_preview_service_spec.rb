require 'rails_helper'

RSpec.describe KanbanAutomations::WorkflowPreviewService do
  it 'previews a webhook connection by name without exposing its URL or secret' do
    board = create(:kanban_board)
    card = create(:kanban_card, account: board.account, kanban_board: board)
    connection = create(
      :kanban_automation_connection,
      account: board.account,
      kanban_board: board,
      name: 'Agenda clínica',
      webhook_url: 'https://private.example.test/hook'
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

    steps = described_class.new(rule: rule, card: card).perform
    step = steps.find { |item| item['node_id'] == 'webhook' }

    expect(step).to include('connection_name' => 'Agenda clínica')
    expect(step.to_s).not_to include('private.example.test')
  end

  it 'renders message variables with the selected opportunity without sending it' do
    board = create(
      :kanban_board,
      custom_field_definitions: [
        { key: 'origem', label: 'Origem', field_type: 'text' }
      ]
    )
    contact = create(:contact, account: board.account, name: 'Ana')
    card = create(
      :kanban_card,
      account: board.account,
      kanban_board: board,
      contact: contact,
      subject: 'Consulta inicial',
      amount_cents: 12_500,
      custom_field_values: { 'origem' => 'Google' }
    )
    rule = create(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger', data: {} },
          {
            id: 'message',
            type: 'send_message',
            data: {
              channel: 'whatsapp',
              content: 'Olá, {{contact_name}}: {{opportunity_subject}} {{opportunity_amount}} {{field.origem}}',
              opt_in_attribute_key: 'marketing_messages_opt_in'
            }
          },
          { id: 'end', type: 'end', data: {} }
        ],
        edges: [
          { source: 'trigger', target: 'message' },
          { source: 'message', target: 'end' }
        ]
      }
    )

    steps = described_class.new(rule: rule, card: card).perform

    expect(steps).to include(
      hash_including(
        'node_id' => 'message',
        'rendered_content' => 'Olá, Ana: Consulta inicial 125.00 Google'
      )
    )
    expect(Message.count).to eq(0)
  end

  it 'includes the business-hours wait in a visual workflow preview' do
    card = create(:kanban_card)
    rule = create(
      :kanban_automation_rule,
      account: card.account,
      kanban_board: card.kanban_board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger', data: {} },
          {
            id: 'business-hours',
            type: 'wait_for_business_hours',
            data: {
              weekdays: [1, 2, 3, 4, 5],
              start_time: '09:00',
              end_time: '18:00',
              timezone: 'America/Sao_Paulo'
            }
          },
          { id: 'end', type: 'end', data: {} }
        ],
        edges: [
          { source: 'trigger', target: 'business-hours' },
          { source: 'business-hours', target: 'end' }
        ]
      }
    )

    steps = described_class.new(rule: rule, card: card).perform

    expect(steps).to include(
      hash_including('node_id' => 'business-hours', 'type' => 'wait_for_business_hours')
    )
  end

  it 'shows the configured random delay range without scheduling a real message' do
    card = create(:kanban_card)
    rule = create(
      :kanban_automation_rule,
      account: card.account,
      kanban_board: card.kanban_board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger', data: {} },
          { id: 'spread', type: 'random_delay', data: { min_minutes: 10, max_minutes: 30 } },
          { id: 'end', type: 'end', data: {} }
        ],
        edges: [
          { source: 'trigger', target: 'spread' },
          { source: 'spread', target: 'end' }
        ]
      }
    )

    steps = described_class.new(rule: rule, card: card).perform

    expect(steps).to include(
      hash_including(
        'node_id' => 'spread',
        'type' => 'random_delay',
        'min_minutes' => 10,
        'max_minutes' => 30
      )
    )
  end

  it 'shows that a stage guard stops the preview after the opportunity moves' do
    board = create(:kanban_board)
    source_stage = create(:kanban_stage, account: board.account, kanban_board: board)
    other_stage = create(:kanban_stage, account: board.account, kanban_board: board)
    card = create(:kanban_card, account: board.account, kanban_board: board, kanban_stage: other_stage)
    rule = create(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      conditions: { stage_ids: [source_stage.id] },
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger', data: {} },
          { id: 'guard', type: 'stage_guard', data: {} },
          { id: 'end', type: 'end', data: {} }
        ],
        edges: [
          { source: 'trigger', target: 'guard' },
          { source: 'guard', target: 'end' }
        ]
      }
    )

    steps = described_class.new(rule: rule, card: card).perform

    expect(steps).to include(
      hash_including('node_id' => 'guard', 'type' => 'stage_guard', 'matched' => false)
    )
  end

  it 'explains when a date wait has already passed for the selected opportunity' do
    board = create(
      :kanban_board,
      custom_field_definitions: [
        { key: 'consultation_at', label: 'Consulta', field_type: 'datetime' }
      ]
    )
    card = create(
      :kanban_card,
      account: board.account,
      kanban_board: board,
      custom_field_values: { 'consultation_at' => '2026-07-20T10:00:00-03:00' }
    )
    rule = create(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger', data: {} },
          {
            id: 'wait',
            type: 'wait_until_field',
            data: {
              field_key: 'consultation_at',
              offset_hours: -24,
              timezone: 'America/Sao_Paulo'
            }
          },
          { id: 'end', type: 'end', data: {} }
        ],
        edges: [
          { source: 'trigger', target: 'wait' },
          { source: 'wait', target: 'end' }
        ]
      }
    )

    steps = described_class.new(rule: rule, card: card, now: Time.zone.parse('2026-07-21 12:00:00')).perform

    expect(steps).to include(
      hash_including(
        'node_id' => 'wait',
        'status' => 'skipped',
        'reason' => 'scheduled_time_in_past',
        'scheduled_at' => '2026-07-19T10:00:00-03:00'
      )
    )
  end

  it 'shows the selected commercial team in a human handoff preview' do
    board = create(:kanban_board)
    card = create(:kanban_card, account: board.account, kanban_board: board)
    team = create(:team, account: board.account)
    rule = create(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger', data: {} },
          { id: 'handoff', type: 'human_handoff', data: { team_id: team.id } }
        ],
        edges: [{ source: 'trigger', target: 'handoff' }]
      }
    )

    steps = described_class.new(rule: rule, card: card).perform

    expect(steps).to include(
      hash_including('node_id' => 'handoff', 'type' => 'human_handoff', 'team_id' => team.id)
    )
  end
end
