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
end
