require 'rails_helper'

RSpec.describe KanbanAutomations::DispatchOverdueNextActionsService do
  it 'iterates overdue opportunities in bounded batches' do
    cards = instance_double(ActiveRecord::Relation)
    where_chain = instance_double(ActiveRecord::QueryMethods::WhereChain)

    allow(KanbanCard).to receive(:open_opportunities).and_return(cards)
    allow(cards).to receive(:where).with(no_args).and_return(where_chain)
    allow(where_chain).to receive(:not).with(next_action_at: nil).and_return(cards)
    allow(cards).to receive(:where).with('next_action_at < ?', anything).and_return(cards)
    allow(cards).to receive(:where).with(next_action_completed_at: nil).and_return(cards)
    expect(cards).to receive(:find_each).with(batch_size: described_class::BATCH_SIZE)

    described_class.new.perform!
  end

  it 'dispatches an overdue next-action rule once per card and day' do
    now = Time.zone.parse('2026-08-04 10:00:00')
    card = create(:kanban_card, next_action_at: now - 1.hour, next_action_completed_at: nil)
    rule = create(
      :kanban_automation_rule,
      account: card.account,
      kanban_board: card.kanban_board,
      event_name: Events::Types::KANBAN_CARD_NEXT_ACTION_OVERDUE
    )

    expect do
      described_class.new(now: now).perform!
    end.to have_enqueued_job(KanbanAutomations::ExecuteRuleJob).with(
      rule.id,
      Events::Types::KANBAN_CARD_NEXT_ACTION_OVERDUE,
      "next-action-overdue:#{card.id}:2026-08-04",
      card.id
    )
  end
end
