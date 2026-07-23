require 'rails_helper'

RSpec.describe KanbanAutomations::ContinueWorkflowJob do
  it 'resumes a waiting visual workflow at its saved next node' do
    card = create(:kanban_card)
    rule = create(
      :kanban_automation_rule,
      account: card.account,
      kanban_board: card.kanban_board,
      flow_definition: waiting_flow_definition
    )
    execution = create_waiting_execution(rule, card)

    described_class.perform_now(execution.id, card.id)

    expect(execution.reload).to have_attributes(status: 'succeeded', workflow_state: {}, scheduled_at: nil)
  end

  it 'skips a waiting workflow when its rule is disabled before it resumes' do
    card = create(:kanban_card)
    rule = create(
      :kanban_automation_rule,
      account: card.account,
      kanban_board: card.kanban_board,
      active: false,
      flow_definition: waiting_flow_definition
    )
    execution = create_waiting_execution(rule, card)

    described_class.perform_now(execution.id, card.id)

    expect(execution.reload).to have_attributes(status: 'skipped', scheduled_at: nil)
  end

  def waiting_flow_definition
    {
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
  end

  def create_waiting_execution(rule, card)
    create(
      :kanban_automation_execution,
      account: card.account,
      kanban_automation_rule: rule,
      status: 'waiting',
      workflow_state: { 'next_node_id' => 'end' },
      scheduled_at: 1.minute.ago
    )
  end
end
