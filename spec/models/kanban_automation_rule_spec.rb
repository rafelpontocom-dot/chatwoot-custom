require 'rails_helper'

RSpec.describe KanbanAutomationRule do
  it 'exposes a human-readable version from optimistic locking' do
    rule = create(:kanban_automation_rule)

    expect(rule.version_number).to eq(1)

    rule.update!(description: 'Revisada pelo administrador')

    expect(rule.version_number).to eq(2)
  end

  it 'accepts board-scoped conditions and internal actions' do
    board = create(
      :kanban_board,
      custom_field_definitions: [{ key: 'origem', label: 'Origem', field_type: 'text' }]
    )
    stage = create(:kanban_stage, account: board.account, kanban_board: board)
    target_stage = create(:kanban_stage, account: board.account, kanban_board: board)
    inbox = create(:inbox, account: board.account)
    owner = create(:user, account: board.account)
    rule = build(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      conditions: {
        inbox_ids: [inbox.id],
        stage_ids: [stage.id],
        owner_ids: [owner.id],
        fields: [{ field_key: 'origem', operator: 'equals', value: 'Mídia Paga' }]
      },
      actions: [{ action_name: 'move_stage', action_params: { stage_id: target_stage.id } }]
    )

    expect(rule).to be_valid
  end

  it 'rejects unsupported events, field operators and actions' do
    rule = build(
      :kanban_automation_rule,
      event_name: 'conversation.created',
      conditions: { fields: [{ field_key: 'origem', operator: 'matches_regex' }] },
      actions: [{ action_name: 'send_message', action_params: {} }]
    )

    expect(rule).not_to be_valid
    expect(rule.errors[:event_name]).to be_present
    expect(rule.errors[:conditions]).to be_present
    expect(rule.errors[:actions]).to be_present
  end

  it 'rejects references outside the board configuration' do
    rule = build(
      :kanban_automation_rule,
      conditions: { stage_ids: [999_999], fields: [{ field_key: 'unknown', operator: 'equals', value: 'x' }] },
      actions: [{ action_name: 'move_stage', action_params: { stage_id: 999_999 } }]
    )

    expect(rule).not_to be_valid
    expect(rule.errors[:stage_ids]).to be_present
    expect(rule.errors[:actions]).to be_present
    expect(rule.errors[:conditions]).to include('Field unknown does not belong to this board')
  end

  it 'rejects a visual workflow with an unsupported node type' do
    rule = build(
      :kanban_automation_rule,
      flow_definition: {
        nodes: [{ id: 'trigger', type: 'trigger' }, { id: 'unknown', type: 'teleport' }],
        edges: [{ source: 'trigger', target: 'unknown' }]
      }
    )

    expect(rule).not_to be_valid
    expect(rule.errors[:flow_definition]).to be_present
  end

  it 'rejects a routed date wait without both result paths' do
    board = create(
      :kanban_board,
      custom_field_definitions: [{ key: 'consultation_at', label: 'Consulta', field_type: 'datetime' }]
    )
    rule = build(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger' },
          {
            id: 'wait',
            type: 'wait_until_field',
            data: {
              field_key: 'consultation_at', offset_hours: -24, failure_mode: 'route'
            }
          },
          { id: 'end', type: 'end' }
        ],
        edges: [
          { source: 'trigger', target: 'wait' },
          { source: 'wait', sourceHandle: 'succeeded', target: 'end' }
        ]
      }
    )

    expect(rule).not_to be_valid
    expect(rule.errors[:flow_definition]).to include('Date wait node wait needs available and unavailable paths')
  end

  it 'rejects a routed response wait without response and timeout paths' do
    rule = build(
      :kanban_automation_rule,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger' },
          { id: 'reply', type: 'wait_for_response', data: { timeout_hours: 24, timeout_mode: 'route' } },
          { id: 'end', type: 'end' }
        ],
        edges: [
          { source: 'trigger', target: 'reply' },
          { source: 'reply', sourceHandle: 'received', target: 'end' }
        ]
      }
    )

    expect(rule).not_to be_valid
    expect(rule.errors[:flow_definition]).to include('Response wait node reply needs received and timeout paths')
  end

  it 'rejects a routed inactivity wait without inactivity and response paths' do
    rule = build(
      :kanban_automation_rule,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger' },
          { id: 'inactive', type: 'wait_for_inactivity', data: { timeout_hours: 24, interruption_mode: 'route' } },
          { id: 'end', type: 'end' }
        ],
        edges: [
          { source: 'trigger', target: 'inactive' },
          { source: 'inactive', sourceHandle: 'inactive', target: 'end' }
        ]
      }
    )

    expect(rule).not_to be_valid
    expect(rule.errors[:flow_definition]).to include('Inactivity wait node inactive needs inactivity and response paths')
  end

  it 'rejects a routed business-hours wait without available and unavailable paths' do
    rule = build(
      :kanban_automation_rule,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger' },
          {
            id: 'business-hours',
            type: 'wait_for_business_hours',
            data: {
              weekdays: [1, 2, 3, 4, 5], start_time: '09:00', end_time: '18:00',
              timezone: 'America/Sao_Paulo', failure_mode: 'route'
            }
          },
          { id: 'end', type: 'end' }
        ],
        edges: [
          { source: 'trigger', target: 'business-hours' },
          { source: 'business-hours', sourceHandle: 'succeeded', target: 'end' }
        ]
      }
    )

    expect(rule).not_to be_valid
    expect(rule.errors[:flow_definition]).to include('Business-hours node business-hours needs available and unavailable paths')
  end

  it 'rejects a message node without content and opt-in' do
    rule = build(
      :kanban_automation_rule,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger' },
          { id: 'message', type: 'send_message', data: { channel: 'whatsapp', content: '' } }
        ],
        edges: [{ source: 'trigger', target: 'message' }]
      }
    )

    expect(rule).not_to be_valid
    expect(rule.errors[:flow_definition]).to be_present
  end

  it 'rejects incomplete quiet hours on a message node' do
    rule = build(
      :kanban_automation_rule,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger' },
          {
            id: 'message',
            type: 'send_message',
            data: {
              channel: 'whatsapp', content: 'Olá', opt_in_attribute_key: 'marketing_messages_opt_in',
              quiet_hours: { start: '20:00', end: '', timezone: 'America/Sao_Paulo' }
            }
          }
        ],
        edges: [{ source: 'trigger', target: 'message' }]
      }
    )

    expect(rule).not_to be_valid
    expect(rule.errors[:flow_definition]).to include('Message node message is incomplete')
  end

  it 'rejects visual actions that reference another board' do
    board = create(:kanban_board)
    rule = build(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger' },
          { id: 'move', type: 'action', data: { action_name: 'move_stage', action_params: { stage_id: 999_999 } } }
        ],
        edges: [{ source: 'trigger', target: 'move' }]
      }
    )

    expect(rule).not_to be_valid
    expect(rule.errors[:flow_definition]).to include('Action node move references a stage outside this board')
  end

  it 'rejects a visual cadence action outside the board' do
    board = create(:kanban_board)
    rule = build(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger' },
          { id: 'cadence', type: 'action', data: { action_name: 'enroll_cadence', action_params: { cadence_id: 999_999 } } }
        ],
        edges: [{ source: 'trigger', target: 'cadence' }]
      }
    )

    expect(rule).not_to be_valid
    expect(rule.errors[:flow_definition]).to include('Action node cadence references a cadence outside this board')
  end

  it 'rejects a legacy cadence action outside the board' do
    board = create(:kanban_board)
    rule = build(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      actions: [{ action_name: 'enroll_cadence', action_params: { cadence_id: 999_999 } }]
    )

    expect(rule).not_to be_valid
    expect(rule.errors[:actions]).to include('Reference 999999 does not belong to this board')
  end

  it 'requires yes and no paths for a condition node' do
    board = create(
      :kanban_board,
      custom_field_definitions: [{ key: 'origem', label: 'Origem', field_type: 'text' }]
    )
    rule = build(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger' },
          { id: 'condition', type: 'condition', data: { field_key: 'origem', operator: 'equals', value: 'Google' } },
          { id: 'end', type: 'end' }
        ],
        edges: [
          { source: 'trigger', target: 'condition' },
          { source: 'condition', sourceHandle: 'yes', target: 'end' }
        ]
      }
    )

    expect(rule).not_to be_valid
    expect(rule.errors[:flow_definition]).to include('Condition node condition needs yes and no paths')
  end

  it 'accepts a filter node with one passing path' do
    board = create(
      :kanban_board,
      custom_field_definitions: [{ key: 'origem', label: 'Origem', field_type: 'text' }]
    )
    rule = build(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger' },
          { id: 'filter', type: 'filter', data: { field_key: 'origem', operator: 'equals', value: 'Google' } },
          { id: 'end', type: 'end' }
        ],
        edges: [
          { source: 'trigger', target: 'filter' },
          { source: 'filter', target: 'end' }
        ]
      }
    )

    expect(rule).to be_valid
  end

  it 'rejects an unsupported connector between workflow conditions' do
    board = create(
      :kanban_board,
      custom_field_definitions: [{ key: 'origem', label: 'Origem', field_type: 'text' }]
    )
    rule = build(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger' },
          {
            id: 'filter',
            type: 'filter',
            data: {
              conditions: [
                { field_key: 'origem', operator: 'equals', value: 'Google' },
                { join_operator: 'xor', field_key: 'origem', operator: 'equals', value: 'Meta' }
              ]
            }
          },
          { id: 'end', type: 'end' }
        ],
        edges: [
          { source: 'trigger', target: 'filter' },
          { source: 'filter', target: 'end' }
        ]
      }
    )

    expect(rule).not_to be_valid
    expect(rule.errors[:flow_definition]).to include('Filter node filter is incomplete')
  end

  it 'requires an internal note for an audit log node' do
    board = create(:kanban_board)
    rule = build(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger' },
          { id: 'audit', type: 'audit_log', data: { content: '' } },
          { id: 'end', type: 'end' }
        ],
        edges: [
          { source: 'trigger', target: 'audit' },
          { source: 'audit', target: 'end' }
        ]
      }
    )

    expect(rule).not_to be_valid
    expect(rule.errors[:flow_definition]).to include('Audit log node audit needs a note')
  end

  it 'rejects a contact update node without a safe attribute key' do
    board = create(:kanban_board)
    rule = build(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger' },
          { id: 'contact', type: 'update_contact', data: { action_params: { attribute_key: 'name', value: 'Ana' } } },
          { id: 'end', type: 'end' }
        ],
        edges: [
          { source: 'trigger', target: 'contact' },
          { source: 'contact', target: 'end' }
        ]
      }
    )

    expect(rule).not_to be_valid
    expect(rule.errors[:flow_definition]).to include('Contact update node contact needs a safe custom attribute key')
  end

  it 'rejects a contact update node with an invalid consent value' do
    board = create(:kanban_board)
    rule = build(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger' },
          {
            id: 'contact',
            type: 'update_contact',
            data: { action_params: { attribute_key: 'marketing_messages_opt_in', value: 'perhaps' } }
          },
          { id: 'end', type: 'end' }
        ],
        edges: [
          { source: 'trigger', target: 'contact' },
          { source: 'contact', target: 'end' }
        ]
      }
    )

    expect(rule).not_to be_valid
    expect(rule.errors[:flow_definition]).to include('Contact update node contact needs a true or false consent value')
  end

  it 'rejects an incomplete follow-up action after completion' do
    board = create(:kanban_board)
    rule = build(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger' },
          {
            id: 'complete',
            type: 'complete_next_action',
            data: { action_params: { next_action_type: 'Ligar para confirmar' } }
          },
          { id: 'end', type: 'end' }
        ],
        edges: [
          { source: 'trigger', target: 'complete' },
          { source: 'complete', target: 'end' }
        ]
      }
    )

    expect(rule).not_to be_valid
    expect(rule.errors[:flow_definition]).to include('Completion node complete needs a next action type and date together')
  end

  it 'rejects an invalid follow-up date after completion' do
    board = create(:kanban_board)
    rule = build(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger' },
          {
            id: 'complete',
            type: 'complete_next_action',
            data: {
              action_params: {
                next_action_type: 'Ligar para confirmar',
                next_action_at: 'data inválida'
              }
            }
          },
          { id: 'end', type: 'end' }
        ],
        edges: [
          { source: 'trigger', target: 'complete' },
          { source: 'complete', target: 'end' }
        ]
      }
    )

    expect(rule).not_to be_valid
    expect(rule.errors[:flow_definition]).to include('Completion node complete needs a valid next action date')
  end

  it 'requires both paths for a message eligibility node' do
    board = create(:kanban_board)
    rule = build(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger' },
          {
            id: 'eligible',
            type: 'message_eligibility',
            data: { channel: 'whatsapp', opt_in_attribute_key: 'marketing_messages_opt_in' }
          },
          { id: 'end', type: 'end' }
        ],
        edges: [
          { source: 'trigger', target: 'eligible' },
          { source: 'eligible', sourceHandle: 'eligible', target: 'end' }
        ]
      }
    )

    expect(rule).not_to be_valid
    expect(rule.errors[:flow_definition]).to include('Message eligibility node eligible needs eligible and otherwise paths')
  end

  it 'requires success and failure paths when webhook failure routing is enabled' do
    board = create(:kanban_board)
    connection = create(:kanban_automation_connection, account: board.account, kanban_board: board)
    rule = build(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger' },
          { id: 'webhook', type: 'webhook', data: { connection_id: connection.id, failure_mode: 'route' } },
          { id: 'end', type: 'end' }
        ],
        edges: [
          { source: 'trigger', target: 'webhook' },
          { source: 'webhook', sourceHandle: 'succeeded', target: 'end' }
        ]
      }
    )

    expect(rule).not_to be_valid
    expect(rule.errors[:flow_definition]).to include('Webhook node webhook needs succeeded and failed paths')
  end

  it 'rejects an inactivity wait without a positive timeout' do
    rule = build(
      :kanban_automation_rule,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger' },
          { id: 'inactivity', type: 'wait_for_inactivity', data: { timeout_hours: 0 } },
          { id: 'end', type: 'end' }
        ],
        edges: [
          { source: 'trigger', target: 'inactivity' },
          { source: 'inactivity', target: 'end' }
        ]
      }
    )

    expect(rule).not_to be_valid
    expect(rule.errors[:flow_definition]).to include('Inactivity wait node inactivity needs positive timeout hours')
  end

  it 'accepts a terminal handoff node for an account agent' do
    board = create(:kanban_board)
    owner = create(:user, account: board.account)
    rule = build(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger' },
          { id: 'handoff', type: 'human_handoff', data: { owner_id: owner.id, note: 'Assumir atendimento' } }
        ],
        edges: [{ source: 'trigger', target: 'handoff' }]
      }
    )

    expect(rule).to be_valid
  end

  it 'rejects cycles in a visual workflow' do
    rule = build(
      :kanban_automation_rule,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger' },
          { id: 'wait', type: 'delay', data: { delay_hours: 1 } }
        ],
        edges: [
          { source: 'trigger', target: 'wait' },
          { source: 'wait', target: 'trigger' }
        ]
      }
    )

    expect(rule).not_to be_valid
    expect(rule.errors[:flow_definition]).to include('must not contain cycles')
  end
end
