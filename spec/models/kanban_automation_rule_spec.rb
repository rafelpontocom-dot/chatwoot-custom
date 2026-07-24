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
