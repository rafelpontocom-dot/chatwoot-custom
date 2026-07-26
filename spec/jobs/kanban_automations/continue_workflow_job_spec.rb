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

  it 'does not repeat a resumed action when the same continuation runs twice' do
    card = create(:kanban_card)
    rule = create(
      :kanban_automation_rule,
      account: card.account,
      kanban_board: card.kanban_board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger', data: {} },
          { id: 'wait', type: 'delay', data: { delay_hours: 24 } },
          { id: 'audit', type: 'audit_log', data: { content: 'Retomada do follow-up' } },
          { id: 'end', type: 'end', data: {} }
        ],
        edges: [
          { source: 'trigger', target: 'wait' },
          { source: 'wait', target: 'audit' },
          { source: 'audit', target: 'end' }
        ]
      }
    )
    execution = create_waiting_execution(rule, card, next_node_id: 'audit')

    2.times { described_class.perform_now(execution.id, card.id) }

    expect(execution.reload).to be_succeeded
    expect(card.kanban_card_events.where(event_type: 'automation_logged').count).to eq(1)
  end

  it 'follows the timeout branch when a response wait expires' do
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
            data: { timeout_hours: 24, timeout_mode: 'route' }
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
    execution = create_waiting_execution(
      rule,
      card,
      next_node_id: 'received',
      waiting_for: 'customer_message',
      timeout_node_id: 'expired'
    )

    described_class.perform_now(execution.id, card.id)

    expect(execution.reload).to be_succeeded
    expect(execution.action_results).to include(
      hash_including('status' => 'skipped', 'reason' => 'response_timeout')
    )
  end

  it 'keeps a transient resume failure reprocessable while Active Job schedules retry' do
    card = create(:kanban_card)
    rule = create(
      :kanban_automation_rule,
      account: card.account,
      kanban_board: card.kanban_board,
      flow_definition: waiting_flow_definition
    )
    execution = create_waiting_execution(rule, card)
    attempts = 0
    allow(KanbanAutomations::WorkflowService).to receive(:new).and_wrap_original do |original, *args|
      attempts += 1
      raise StandardError, 'temporary database timeout' if attempts == 1

      original.call(*args)
    end

    described_class.perform_now(execution.id, card.id)

    expect(attempts).to eq(1)
    expect(execution.reload).to have_attributes(status: 'waiting', error_message: nil, completed_at: nil)
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

  def create_waiting_execution(rule, card, next_node_id: 'end', waiting_for: nil, timeout_node_id: nil)
    workflow_state = { 'next_node_id' => next_node_id }
    workflow_state['waiting_for'] = waiting_for if waiting_for.present?
    workflow_state['timeout_node_id'] = timeout_node_id if timeout_node_id.present?

    create(
      :kanban_automation_execution,
      account: card.account,
      kanban_automation_rule: rule,
      status: 'waiting',
      workflow_state: workflow_state,
      scheduled_at: 1.minute.ago
    )
  end
end
