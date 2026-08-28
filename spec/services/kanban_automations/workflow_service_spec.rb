require 'rails_helper'

RSpec.describe KanbanAutomations::WorkflowService do
  it 'records a semantic failed end state without raising an execution error' do
    card = create(:kanban_card)
    rule = create(
      :kanban_automation_rule,
      account: card.account,
      kanban_board: card.kanban_board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger', data: {} },
          { id: 'end', type: 'end', data: { outcome: 'failed' } }
        ],
        edges: [{ source: 'trigger', target: 'end' }]
      }
    )
    execution = create(:kanban_automation_execution, account: card.account, kanban_automation_rule: rule, kanban_card: card)

    result = described_class.new(execution: execution, rule: rule, card: card).perform!

    expect(result[:status]).to eq(:failed)
    expect(result[:action_results]).to include(hash_including('outcome' => 'failed'))
  end

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
    expect(result[:action_results]).to include(
      hash_including('node_id' => 'wait', 'executed_at' => now.iso8601)
    )
  end

  it 'spreads a commercial follow-up within a configured random minute interval' do
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
    execution = create(:kanban_automation_execution, account: card.account, kanban_automation_rule: rule)
    now = Time.zone.parse('2026-07-31 12:00:00')

    allow(Kernel).to receive(:rand).with(10..30).and_return(17)

    result = described_class.new(execution: execution, rule: rule, card: card, now: now).perform!

    expect(result).to include(status: :waiting, scheduled_at: now + 17.minutes)
    expect(result[:workflow_state]).to include('next_node_id' => 'end')
    expect(result[:action_results]).to include(
      hash_including('node_id' => 'spread', 'delay_minutes' => 17)
    )
  end

  it 'stops a follow-up when the opportunity leaves the trigger stage' do
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
    execution = create(:kanban_automation_execution, account: board.account, kanban_automation_rule: rule)

    result = described_class.new(execution: execution, rule: rule, card: card).perform!

    expect(result[:status]).to eq(:succeeded)
    expect(result[:action_results]).to include(
      hash_including('node_id' => 'guard', 'status' => 'skipped', 'reason' => 'stage_changed')
    )
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
    execution = create(
      :kanban_automation_execution,
      account: card.account,
      kanban_automation_rule: rule,
      kanban_card: card,
      workflow_state: { event_data: { payment_id: 42 } }
    )
    now = Time.zone.parse('2026-07-23 10:00:00')

    result = described_class.new(execution: execution, rule: rule, card: card, now: now).perform!

    expect(result).to include(status: :waiting, scheduled_at: now + 48.hours)
    expect(result[:workflow_state]).to include(
      'next_node_id' => 'end',
      'waiting_for' => 'customer_message',
      'event_data' => { 'payment_id' => 42 }
    )
  end

  it 'stores separate response and timeout paths when the response wait is routed' do
    card = create(:kanban_card)
    rule = create(
      :kanban_automation_rule,
      account: card.account,
      kanban_board: card.kanban_board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger', data: {} },
          {
            id: 'reply',
            type: 'wait_for_response',
            data: { timeout_hours: 48, timeout_mode: 'route' }
          },
          { id: 'received', type: 'end', data: {} },
          { id: 'expired', type: 'end', data: {} }
        ],
        edges: [
          { source: 'trigger', target: 'reply' },
          { source: 'reply', sourceHandle: 'received', target: 'received' },
          { source: 'reply', sourceHandle: 'timeout', target: 'expired' }
        ]
      }
    )
    execution = create(:kanban_automation_execution, account: card.account, kanban_automation_rule: rule, kanban_card: card)

    result = described_class.new(execution: execution, rule: rule, card: card).perform!

    expect(result[:workflow_state]).to include(
      'next_node_id' => 'received',
      'timeout_node_id' => 'expired',
      'waiting_for' => 'customer_message'
    )
  end

  it 'stops a workflow at a filter when the opportunity does not match' do
    board = create(
      :kanban_board,
      custom_field_definitions: [{ key: 'origem', label: 'Origem', field_type: 'text' }]
    )
    card = create(
      :kanban_card,
      account: board.account,
      kanban_board: board,
      custom_field_values: { origem: 'Parceria' }
    )
    rule = create(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger', data: {} },
          { id: 'filter', type: 'filter', data: { field_key: 'origem', operator: 'equals', value: 'Google' } },
          { id: 'end', type: 'end', data: {} }
        ],
        edges: [
          { source: 'trigger', target: 'filter' },
          { source: 'filter', target: 'end' }
        ]
      }
    )
    execution = create(:kanban_automation_execution, account: board.account, kanban_automation_rule: rule)

    result = described_class.new(execution: execution, rule: rule, card: card).perform!

    expect(result[:status]).to eq(:succeeded)
    expect(result[:action_results]).to include(
      hash_including('node_id' => 'filter', 'status' => 'skipped', 'reason' => 'filter_not_matched')
    )
  end

  it 'adds an immutable internal audit event and continues the workflow' do
    card = create(:kanban_card)
    rule = create(
      :kanban_automation_rule,
      account: card.account,
      kanban_board: card.kanban_board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger', data: {} },
          { id: 'audit', type: 'audit_log', data: { content: 'Lead passou pela triagem.' } },
          { id: 'end', type: 'end', data: {} }
        ],
        edges: [
          { source: 'trigger', target: 'audit' },
          { source: 'audit', target: 'end' }
        ]
      }
    )
    execution = create(:kanban_automation_execution, account: card.account, kanban_automation_rule: rule)

    result = described_class.new(execution: execution, rule: rule, card: card).perform!

    expect(result[:status]).to eq(:succeeded)
    expect(card.kanban_card_events.order(:id).last).to have_attributes(
      event_type: 'automation_logged',
      metadata: hash_including('content' => 'Lead passou pela triagem.', 'automation_rule_id' => rule.id)
    )
  end

  it 'follows the otherwise path when a message is not eligible' do
    card = create(:kanban_card)
    rule = create(
      :kanban_automation_rule,
      account: card.account,
      kanban_board: card.kanban_board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger', data: {} },
          {
            id: 'eligible',
            type: 'message_eligibility',
            data: { channel: 'whatsapp', opt_in_attribute_key: 'marketing_messages_opt_in' }
          },
          { id: 'eligible-end', type: 'end', data: {} },
          { id: 'otherwise-end', type: 'end', data: {} }
        ],
        edges: [
          { source: 'trigger', target: 'eligible' },
          { source: 'eligible', sourceHandle: 'eligible', target: 'eligible-end' },
          { source: 'eligible', sourceHandle: 'otherwise', target: 'otherwise-end' }
        ]
      }
    )
    execution = create(:kanban_automation_execution, account: card.account, kanban_automation_rule: rule)

    result = described_class.new(execution: execution, rule: rule, card: card).perform!

    expect(result[:status]).to eq(:succeeded)
    expect(result[:action_results]).to include(
      hash_including('node_id' => 'eligible', 'branch' => 'otherwise', 'reason' => 'no_compatible_conversation')
    )
  end

  it 'waits for customer inactivity before continuing the workflow' do
    card = create(:kanban_card)
    rule = create(
      :kanban_automation_rule,
      account: card.account,
      kanban_board: card.kanban_board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger', data: {} },
          { id: 'inactive', type: 'wait_for_inactivity', data: { timeout_hours: 24 } },
          { id: 'end', type: 'end', data: {} }
        ],
        edges: [
          { source: 'trigger', target: 'inactive' },
          { source: 'inactive', target: 'end' }
        ]
      }
    )
    execution = create(:kanban_automation_execution, account: card.account, kanban_automation_rule: rule)
    now = Time.zone.parse('2026-08-01 12:00:00')

    result = described_class.new(execution: execution, rule: rule, card: card, now: now).perform!

    expect(result).to include(status: :waiting, scheduled_at: now + 24.hours)
    expect(result[:workflow_state]).to include('next_node_id' => 'end', 'waiting_for' => 'customer_inactivity')
  end

  it 'stores separate inactivity and response paths when the inactivity wait is routed' do
    card = create(:kanban_card)
    rule = create(
      :kanban_automation_rule,
      account: card.account,
      kanban_board: card.kanban_board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger', data: {} },
          {
            id: 'inactive',
            type: 'wait_for_inactivity',
            data: { timeout_hours: 24, interruption_mode: 'route' }
          },
          { id: 'idle', type: 'end', data: {} },
          { id: 'responded', type: 'end', data: {} }
        ],
        edges: [
          { source: 'trigger', target: 'inactive' },
          { source: 'inactive', sourceHandle: 'inactive', target: 'idle' },
          { source: 'inactive', sourceHandle: 'responded', target: 'responded' }
        ]
      }
    )
    execution = create(:kanban_automation_execution, account: card.account, kanban_automation_rule: rule, kanban_card: card)

    result = described_class.new(execution: execution, rule: rule, card: card).perform!

    expect(result[:workflow_state]).to include(
      'next_node_id' => 'idle',
      'response_node_id' => 'responded',
      'waiting_for' => 'customer_inactivity'
    )
  end

  it 'hands the opportunity to an agent and ends the workflow' do
    card = create(:kanban_card)
    owner = create(:user, account: card.account)
    rule = create(
      :kanban_automation_rule,
      account: card.account,
      kanban_board: card.kanban_board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger', data: {} },
          { id: 'handoff', type: 'human_handoff', data: { owner_id: owner.id } }
        ],
        edges: [{ source: 'trigger', target: 'handoff' }]
      }
    )
    execution = create(:kanban_automation_execution, account: card.account, kanban_automation_rule: rule)

    result = described_class.new(execution: execution, rule: rule, card: card).perform!

    expect(result[:status]).to eq(:succeeded)
    expect(card.reload.owner).to eq(owner)
    expect(result[:action_results]).to include(
      hash_including('node_id' => 'handoff', 'action_name' => 'assign_owner')
    )
  end

  it 'hands a linked conversation to a commercial team and ends the workflow' do
    conversation = create(:conversation)
    card = create(:kanban_card, :conversation_origin, conversation: conversation)
    team = create(:team, account: card.account)
    rule = create(
      :kanban_automation_rule,
      account: card.account,
      kanban_board: card.kanban_board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger', data: {} },
          { id: 'handoff', type: 'human_handoff', data: { team_id: team.id } }
        ],
        edges: [{ source: 'trigger', target: 'handoff' }]
      }
    )
    execution = create(:kanban_automation_execution, account: card.account, kanban_automation_rule: rule)

    result = described_class.new(execution: execution, rule: rule, card: card).perform!

    expect(result[:status]).to eq(:succeeded)
    expect(conversation.reload.team).to eq(team)
    expect(result[:action_results]).to include(
      hash_including('node_id' => 'handoff', 'action_name' => 'assign_team')
    )
  end

  it 'notifies a commercial team with a private conversation mention and continues the workflow' do
    conversation = create(:conversation)
    card = create(:kanban_card, :conversation_origin, conversation: conversation)
    team = create(:team, account: card.account)
    rule = create(
      :kanban_automation_rule,
      account: card.account,
      kanban_board: card.kanban_board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger', data: {} },
          {
            id: 'notify',
            type: 'notify_team',
            data: { team_ids: [team.id], content: 'Revisar esta oportunidade hoje.' }
          },
          { id: 'end', type: 'end', data: {} }
        ],
        edges: [
          { source: 'trigger', target: 'notify' },
          { source: 'notify', target: 'end' }
        ]
      }
    )
    execution = create(:kanban_automation_execution, account: card.account, kanban_automation_rule: rule)

    result = described_class.new(execution: execution, rule: rule, card: card).perform!

    expect(result[:status]).to eq(:succeeded)
    expect(conversation.messages.last).to have_attributes(
      private: true,
      content: include('Revisar esta oportunidade hoje.', "(mention://team/#{team.id}/#{team.name})")
    )
    expect(result[:action_results]).to include(
      hash_including('node_id' => 'notify', 'status' => 'succeeded', 'team_ids' => [team.id])
    )
  end

  it 'waits until the next configured business window before a follow-up message' do
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
    execution = create(:kanban_automation_execution, account: card.account, kanban_automation_rule: rule)
    now = Time.find_zone!('America/Sao_Paulo').parse('2026-08-01 20:00:00')

    result = described_class.new(execution: execution, rule: rule, card: card, now: now).perform!

    expect(result).to include(status: :waiting)
    expect(result[:scheduled_at]).to eq(Time.find_zone!('America/Sao_Paulo').parse('2026-08-03 09:00:00'))
    expect(result[:workflow_state]).to include('next_node_id' => 'end')
  end

  it 'follows the unavailable branch when a routed business-hours wait cannot calculate a window' do
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
              weekdays: [1, 2, 3, 4, 5], start_time: '09:00', end_time: '18:00',
              timezone: 'America/Sao_Paulo', failure_mode: 'route'
            }
          },
          { id: 'available', type: 'end', data: {} },
          { id: 'unavailable', type: 'end', data: {} }
        ],
        edges: [
          { source: 'trigger', target: 'business-hours' },
          { source: 'business-hours', sourceHandle: 'succeeded', target: 'available' },
          { source: 'business-hours', sourceHandle: 'failed', target: 'unavailable' }
        ]
      }
    )
    execution = create(:kanban_automation_execution, account: card.account, kanban_automation_rule: rule, kanban_card: card)
    service = described_class.new(execution: execution, rule: rule, card: card)
    allow(service).to receive(:next_business_time).and_raise(ArgumentError, 'no future window')

    result = service.perform!

    expect(result[:status]).to eq(:succeeded)
    expect(result[:action_results]).to include(
      hash_including('node_id' => 'business-hours', 'status' => 'failed', 'reason' => 'business_hours_unavailable')
    )
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

  it 'routes a blocked message through the configured not-sent path' do
    card = create(:kanban_card)
    rule = create(
      :kanban_automation_rule,
      account: card.account,
      kanban_board: card.kanban_board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger', data: {} },
          {
            id: 'message',
            type: 'send_message',
            data: {
              channel: 'whatsapp',
              opt_in_attribute_key: 'marketing_messages_opt_in',
              content: 'Olá',
              failure_mode: 'route'
            }
          },
          { id: 'not-sent', type: 'audit_log', data: { content: 'Mensagem não enviada' } },
          { id: 'end', type: 'end', data: {} }
        ],
        edges: [
          { source: 'trigger', target: 'message' },
          { source: 'message', sourceHandle: 'succeeded', target: 'end' },
          { source: 'message', sourceHandle: 'failed', target: 'not-sent' },
          { source: 'not-sent', target: 'end' }
        ]
      }
    )
    execution = create(:kanban_automation_execution, account: card.account, kanban_automation_rule: rule)

    result = described_class.new(execution: execution, rule: rule, card: card).perform!

    expect(result[:status]).to eq(:succeeded)
    expect(result[:action_results]).to include(
      hash_including('node_id' => 'message', 'status' => 'skipped', 'reason' => 'no_compatible_conversation'),
      hash_including('node_id' => 'not-sent', 'status' => 'succeeded')
    )
  end

  it 'routes an unavailable date field through the configured date path' do
    board = create(
      :kanban_board,
      custom_field_definitions: [{ key: 'consultation_at', label: 'Consulta', field_type: 'datetime' }]
    )
    card = create(:kanban_card, account: board.account, kanban_board: board, custom_field_values: { 'consultation_at' => 'invalid' })
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
              offset_hours: 0,
              timezone: 'America/Sao_Paulo',
              failure_mode: 'route'
            }
          },
          { id: 'unavailable', type: 'audit_log', data: { content: 'Data indisponível' } },
          { id: 'end', type: 'end', data: {} }
        ],
        edges: [
          { source: 'trigger', target: 'wait' },
          { source: 'wait', sourceHandle: 'succeeded', target: 'end' },
          { source: 'wait', sourceHandle: 'failed', target: 'unavailable' },
          { source: 'unavailable', target: 'end' }
        ]
      }
    )
    execution = create(:kanban_automation_execution, account: board.account, kanban_automation_rule: rule)

    result = described_class.new(execution: execution, rule: rule, card: card).perform!

    expect(result[:status]).to eq(:succeeded)
    expect(result[:action_results]).to include(
      hash_including('node_id' => 'wait', 'status' => 'failed', 'reason' => 'date_field_unavailable'),
      hash_including('node_id' => 'unavailable', 'status' => 'succeeded')
    )
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

  # rubocop:disable RSpec/ExampleLength
  it 'routes the first matching conditional output and falls back when none match' do
    board = create(
      :kanban_board,
      custom_field_definitions: [
        { key: 'origem', label: 'Origem', field_type: 'select', options: %w[Google Meta Indicação] },
        { key: 'qualificado', label: 'Qualificado', field_type: 'boolean' },
        { key: 'resultado', label: 'Resultado', field_type: 'text' }
      ]
    )
    card = create(
      :kanban_card,
      account: board.account,
      kanban_board: board,
      custom_field_values: { origem: 'Google', qualificado: true }
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
            data: {
              branches: [
                {
                  id: 'google-qualified',
                  label: 'Google qualificado',
                  match_mode: 'all',
                  conditions: [
                    { field_key: 'origem', operator: 'equals', value: 'Google' },
                    { field_key: 'qualificado', operator: 'equals', value: true }
                  ]
                },
                {
                  id: 'meta',
                  label: 'Meta',
                  match_mode: 'all',
                  conditions: [{ field_key: 'origem', operator: 'equals', value: 'Meta' }]
                }
              ],
              fallback_id: 'otherwise'
            }
          },
          { id: 'google-action', type: 'set_field', data: { action_params: { field_key: 'resultado', value: 'Google qualificado' } } },
          { id: 'meta-action', type: 'set_field', data: { action_params: { field_key: 'resultado', value: 'Meta' } } },
          { id: 'otherwise-action', type: 'set_field', data: { action_params: { field_key: 'resultado', value: 'Outros' } } },
          { id: 'end', type: 'end', data: {} }
        ],
        edges: [
          { source: 'trigger', target: 'condition' },
          { source: 'condition', sourceHandle: 'google-qualified', target: 'google-action' },
          { source: 'condition', sourceHandle: 'meta', target: 'meta-action' },
          { source: 'condition', sourceHandle: 'otherwise', target: 'otherwise-action' },
          { source: 'google-action', target: 'end' },
          { source: 'meta-action', target: 'end' },
          { source: 'otherwise-action', target: 'end' }
        ]
      }
    )
    execution = create(:kanban_automation_execution, account: board.account, kanban_automation_rule: rule)

    result = described_class.new(execution: execution, rule: rule, card: card).perform!

    expect(card.reload.custom_field_values).to include('resultado' => 'Google qualificado')
    expect(result[:action_results]).to include(hash_including('node_id' => 'condition', 'branch' => 'google-qualified'))
  end
  # rubocop:enable RSpec/ExampleLength

  # rubocop:disable RSpec/ExampleLength
  it 'evaluates multiple condition rules with an OR match mode' do
    board = create(
      :kanban_board,
      custom_field_definitions: [
        { key: 'origem', label: 'Origem', field_type: 'select', options: ['Orgânico', 'Mídia Paga'] },
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
            data: {
              match_mode: 'any',
              conditions: [
                { field_key: 'origem', operator: 'equals', value: 'Orgânico' },
                { field_key: 'origem', operator: 'equals', value: 'Mídia Paga' }
              ]
            }
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

    described_class.new(execution: execution, rule: rule, card: card).perform!

    expect(card.reload.custom_field_values).to include('resultado' => 'Qualificado')
  end

  it 'evaluates condition connectors in their configured order' do
    board = create(
      :kanban_board,
      custom_field_definitions: [
        { key: 'origem', label: 'Origem', field_type: 'select', options: %w[Google Meta] },
        { key: 'qualificado', label: 'Qualificado', field_type: 'boolean' },
        { key: 'resultado', label: 'Resultado', field_type: 'text' }
      ]
    )
    card = create(
      :kanban_card,
      account: board.account,
      kanban_board: board,
      custom_field_values: { origem: 'Meta', qualificado: true }
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
            data: {
              branches: [
                {
                  id: 'matching',
                  label: 'Correspondente',
                  conditions: [
                    { field_key: 'origem', operator: 'equals', value: 'Google' },
                    { join_operator: 'or', field_key: 'qualificado', operator: 'equals', value: true }
                  ]
                }
              ],
              fallback_id: 'otherwise'
            }
          },
          { id: 'match', type: 'set_field', data: { action_params: { field_key: 'resultado', value: 'Correspondente' } } },
          { id: 'otherwise', type: 'set_field', data: { action_params: { field_key: 'resultado', value: 'Outro' } } },
          { id: 'end', type: 'end', data: {} }
        ],
        edges: [
          { source: 'trigger', target: 'condition' },
          { source: 'condition', sourceHandle: 'matching', target: 'match' },
          { source: 'condition', sourceHandle: 'otherwise', target: 'otherwise' },
          { source: 'match', target: 'end' },
          { source: 'otherwise', target: 'end' }
        ]
      }
    )
    execution = create(:kanban_automation_execution, account: board.account, kanban_automation_rule: rule)

    described_class.new(execution: execution, rule: rule, card: card).perform!

    expect(card.reload.custom_field_values).to include('resultado' => 'Correspondente')
  end
  # rubocop:enable RSpec/ExampleLength

  it 'rotates round-robin options across executions of the same rule' do
    board = create(
      :kanban_board,
      custom_field_definitions: [{ key: 'resultado', label: 'Resultado', field_type: 'text' }]
    )
    card = create(:kanban_card, account: board.account, kanban_board: board)
    rule = create(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger', data: {} },
          {
            id: 'round-robin',
            type: 'round_robin',
            data: {
              options: [
                { id: 'first', label: 'Primeira opção' },
                { id: 'second', label: 'Segunda opção' }
              ]
            }
          },
          {
            id: 'first-action',
            type: 'set_field',
            data: { action_params: { field_key: 'resultado', value: 'Primeira' } }
          },
          {
            id: 'second-action',
            type: 'set_field',
            data: { action_params: { field_key: 'resultado', value: 'Segunda' } }
          },
          { id: 'end', type: 'end', data: {} }
        ],
        edges: [
          { source: 'trigger', target: 'round-robin' },
          { source: 'round-robin', sourceHandle: 'first', target: 'first-action' },
          { source: 'round-robin', sourceHandle: 'second', target: 'second-action' },
          { source: 'first-action', target: 'end' },
          { source: 'second-action', target: 'end' }
        ]
      }
    )

    first_execution = create(:kanban_automation_execution, account: board.account, kanban_automation_rule: rule)
    described_class.new(execution: first_execution, rule: rule, card: card).perform!
    expect(card.reload.custom_field_values).to include('resultado' => 'Primeira')

    second_execution = create(:kanban_automation_execution, account: board.account, kanban_automation_rule: rule)
    described_class.new(execution: second_execution, rule: rule, card: card).perform!
    expect(card.reload.custom_field_values).to include('resultado' => 'Segunda')
  end

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

  it 'interprets a local datetime field in the timezone selected by the wait node' do
    board = create(
      :kanban_board,
      custom_field_definitions: [{ key: 'data_consulta', label: 'Data da consulta', field_type: 'datetime' }]
    )
    card = create(
      :kanban_card,
      account: board.account,
      kanban_board: board,
      custom_field_values: {}
    )
    allow(card).to receive(:custom_field_values).and_return({ 'data_consulta' => '2026-08-10 15:00:00' })
    rule = create(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger', data: {} },
          {
            id: 'appointment',
            type: 'wait_until_field',
            data: { field_key: 'data_consulta', offset_hours: -24, timezone: 'Europe/Lisbon' }
          },
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

    expected = ActiveSupport::TimeZone['Europe/Lisbon'].parse('2026-08-10 15:00:00') - 24.hours
    expect(result).to include(status: :waiting, scheduled_at: expected)
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

  it 'creates a second opportunity from the linked conversation in a selected stage' do
    conversation = create(:conversation)
    card = create(:kanban_card, :conversation_origin, conversation: conversation)
    create(:user, :administrator, account: card.account)
    target_stage = create(:kanban_stage, account: card.account, kanban_board: card.kanban_board)
    rule = create(
      :kanban_automation_rule,
      account: card.account,
      kanban_board: card.kanban_board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger', data: {} },
          {
            id: 'create',
            type: 'create_opportunity',
            data: { stage_id: target_stage.id, subject: 'Retorno comercial' }
          },
          { id: 'end', type: 'end', data: {} }
        ],
        edges: [
          { source: 'trigger', target: 'create' },
          { source: 'create', target: 'end' }
        ]
      }
    )
    execution = create(:kanban_automation_execution, account: card.account, kanban_automation_rule: rule)

    result = nil
    expect do
      result = described_class.new(execution: execution, rule: rule, card: card).perform!
    end.to change(KanbanCard, :count).by(1)

    created_card = card.kanban_board.kanban_cards.find_by!(subject: 'Retorno comercial')
    expect(created_card).to have_attributes(conversation: conversation, kanban_stage: target_stage)
    expect(result[:action_results]).to include(
      hash_including('node_id' => 'create', 'status' => 'succeeded', 'created_card_id' => created_card.id)
    )
  end

  it 'routes to the duplicate path when another active opportunity has the same contact' do
    card = create(:kanban_card)
    duplicate = create(
      :kanban_card,
      account: card.account,
      kanban_board: card.kanban_board,
      contact: card.contact,
      inbox: card.inbox,
      subject: 'Outra oportunidade aberta'
    )
    rule = create(
      :kanban_automation_rule,
      account: card.account,
      kanban_board: card.kanban_board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger', data: {} },
          { id: 'dedupe', type: 'duplicate_check', data: {} },
          { id: 'duplicate-end', type: 'end', data: { outcome: 'stopped' } },
          { id: 'unique-end', type: 'end', data: { outcome: 'completed' } }
        ],
        edges: [
          { source: 'trigger', target: 'dedupe' },
          { source: 'dedupe', sourceHandle: 'duplicate', target: 'duplicate-end' },
          { source: 'dedupe', sourceHandle: 'unique', target: 'unique-end' }
        ]
      }
    )
    execution = create(:kanban_automation_execution, account: card.account, kanban_automation_rule: rule)

    result = described_class.new(execution: execution, rule: rule, card: card).perform!

    expect(result[:status]).to eq(:succeeded)
    expect(result[:action_results]).to include(
      hash_including('node_id' => 'dedupe', 'branch' => 'duplicate', 'duplicate_card_ids' => [duplicate.id])
    )
  end

  it 'routes to the unique path when the current card is the contact only active opportunity' do
    card = create(:kanban_card)
    rule = create(
      :kanban_automation_rule,
      account: card.account,
      kanban_board: card.kanban_board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger', data: {} },
          { id: 'dedupe', type: 'duplicate_check', data: {} },
          { id: 'duplicate-end', type: 'end', data: { outcome: 'stopped' } },
          { id: 'unique-end', type: 'end', data: { outcome: 'completed' } }
        ],
        edges: [
          { source: 'trigger', target: 'dedupe' },
          { source: 'dedupe', sourceHandle: 'duplicate', target: 'duplicate-end' },
          { source: 'dedupe', sourceHandle: 'unique', target: 'unique-end' }
        ]
      }
    )
    execution = create(:kanban_automation_execution, account: card.account, kanban_automation_rule: rule)

    result = described_class.new(execution: execution, rule: rule, card: card).perform!

    expect(result[:status]).to eq(:succeeded)
    expect(result[:action_results]).to include(
      hash_including('node_id' => 'dedupe', 'branch' => 'unique', 'duplicate_card_ids' => [])
    )
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
