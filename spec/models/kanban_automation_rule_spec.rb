require 'rails_helper'

RSpec.describe KanbanAutomationRule do
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
end
