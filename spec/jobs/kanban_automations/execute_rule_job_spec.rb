require 'rails_helper'

RSpec.describe KanbanAutomations::ExecuteRuleJob do
  self.use_transactional_tests = false

  around do |example|
    clean_database!
    example.run
  ensure
    clean_database!
  end

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

  it 'creates one execution when two workers process the same event concurrently' do
    card = create(:kanban_card)
    rule = create(
      :kanban_automation_rule,
      account: card.account,
      kanban_board: card.kanban_board
    )

    errors = run_concurrently(
      -> { described_class.perform_now(rule.id, rule.event_name, 'concurrent-event', card.id) },
      -> { described_class.perform_now(rule.id, rule.event_name, 'concurrent-event', card.id) }
    )

    expect(errors).to be_empty
    expect(rule.kanban_automation_executions.where(event_key: 'concurrent-event')).to have_attributes(count: 1)
    expect(rule.kanban_automation_executions.find_by!(event_key: 'concurrent-event')).to be_succeeded
  end

  it 'keeps a transient workflow failure reprocessable while Active Job schedules retry' do
    card = create(:kanban_card)
    rule = create(
      :kanban_automation_rule,
      account: card.account,
      kanban_board: card.kanban_board,
      flow_definition: {
        nodes: [
          { id: 'trigger', type: 'trigger', data: {} },
          { id: 'end', type: 'end', data: {} }
        ],
        edges: [{ source: 'trigger', target: 'end' }]
      }
    )
    attempts = 0
    allow(KanbanAutomations::WorkflowService).to receive(:new).and_wrap_original do |original, *args|
      attempts += 1
      raise StandardError, 'temporary database timeout' if attempts == 1

      original.call(*args)
    end

    described_class.perform_now(rule.id, rule.event_name, 'retryable-event', card.id)

    execution = rule.kanban_automation_executions.find_by!(event_key: 'retryable-event')
    expect(attempts).to eq(1)
    expect(execution).to have_attributes(status: 'queued', error_message: nil, completed_at: nil)
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

  it 'evaluates the customer reply passed with the event context' do
    card = create(:kanban_card)
    rule = create(
      :kanban_automation_rule,
      account: card.account,
      kanban_board: card.kanban_board,
      event_name: Events::Types::KANBAN_CARD_CUSTOMER_MESSAGE_RECEIVED,
      conditions: { customer_message_contains: 'consulta' },
      actions: [{ action_name: 'add_label', action_params: { label: 'respondeu-consulta' } }]
    )

    described_class.perform_now(
      rule.id,
      rule.event_name,
      'customer-reply-event',
      card.id,
      { event_data: { customer_message_content: 'Quero marcar uma consulta.' } }
    )

    expect(card.reload.labels.pluck(:name)).to include('respondeu-consulta')
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
      'version' => rule.version_number,
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

  def run_concurrently(*operations)
    ready = Queue.new
    start = Queue.new
    errors = Queue.new
    threads = operations.map do |operation|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          start.pop
          operation.call
        rescue StandardError => e
          errors << e
        end
      end
    end

    operations.length.times { ready.pop }
    operations.length.times { start << true }
    threads.each(&:join)
    Array.new(errors.size) { errors.pop }
  end

  def clean_database!
    ActiveRecord::Base.connection_pool.with_connection do |connection|
      connection.disable_referential_integrity do
        (connection.tables - %w[schema_migrations ar_internal_metadata]).each do |table|
          connection.execute("DELETE FROM #{connection.quote_table_name(table)}")
        end
      end
    end
  end
end
