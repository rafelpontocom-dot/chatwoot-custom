require 'rails_helper'

RSpec.describe KanbanAutomations::ExecuteRuleJob do
  it 'executes a matching rule once for the same event key' do
    card = create(:kanban_card)
    target_stage = create(:kanban_stage, account: card.account, kanban_board: card.kanban_board)
    rule = create(
      :kanban_automation_rule,
      account: card.account,
      kanban_board: card.kanban_board,
      actions: [{ action_name: 'move_stage', action_params: { stage_id: target_stage.id } }]
    )

    expect do
      described_class.perform_now(rule.id, rule.event_name, 'same-event', card.id)
      described_class.perform_now(rule.id, rule.event_name, 'same-event', card.id)
    end.to change(KanbanAutomationExecution, :count).by(1)

    expect(card.reload.kanban_stage_id).to eq(target_stage.id)
    expect(rule.kanban_automation_executions.succeeded.count).to eq(1)
  end

  it 'records skipped executions when conditions do not match' do
    card = create(:kanban_card)
    other_owner = create(:user, account: card.account)
    rule = create(
      :kanban_automation_rule,
      account: card.account,
      kanban_board: card.kanban_board,
      conditions: { owner_ids: [other_owner.id] }
    )

    described_class.perform_now(rule.id, rule.event_name, 'skipped-event', card.id)

    expect(rule.kanban_automation_executions.sole.status).to eq('skipped')
  end

  it 'schedules continuation when a visual workflow reaches a delay node' do
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

    described_class.perform_now(rule.id, rule.event_name, 'visual-flow-event', card.id)

    execution = rule.kanban_automation_executions.sole
    expect(execution).to have_attributes(status: 'waiting', workflow_state: { 'next_node_id' => 'end' })
    expect(execution.automation_snapshot).to include(
      'version' => rule.lock_version,
      'flow_definition' => rule.flow_definition
    )
    expect(KanbanAutomations::ContinueWorkflowJob).to have_been_enqueued.with(execution.id, card.id)
  end

  it 'does not re-enter a rule while the same opportunity has a waiting execution' do
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

    described_class.perform_now(rule.id, rule.event_name, 'first-event', card.id)
    described_class.perform_now(rule.id, rule.event_name, 'second-event', card.id)

    skipped_execution = rule.kanban_automation_executions.find_by!(event_key: 'second-event')
    expect(skipped_execution).to have_attributes(status: 'skipped', completed_at: be_present)
    expect(skipped_execution.action_results).to include(hash_including('reason' => 'active_execution_exists'))
  end

  it 'requires explicit re-entry after a workflow has completed for an opportunity' do
    card = create(:kanban_card)
    rule = create(
      :kanban_automation_rule,
      account: card.account,
      kanban_board: card.kanban_board,
      actions: [{ action_name: 'add_label', action_params: { label: 'cadencia-concluida' } }]
    )

    described_class.perform_now(rule.id, rule.event_name, 'completed-event', card.id)
    described_class.perform_now(rule.id, rule.event_name, 'blocked-reentry-event', card.id)

    skipped_execution = rule.kanban_automation_executions.find_by!(event_key: 'blocked-reentry-event')
    expect(skipped_execution.action_results).to include(hash_including('reason' => 'reentry_not_allowed'))
  end
end
