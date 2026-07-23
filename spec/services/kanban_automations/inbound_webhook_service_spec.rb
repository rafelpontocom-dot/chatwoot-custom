require 'rails_helper'

RSpec.describe KanbanAutomations::InboundWebhookService do
  it 'starts matching webhook rules for an active opportunity on the same board' do
    board = create(:kanban_board)
    card = create(:kanban_card, account: board.account, kanban_board: board)
    connection = create(:kanban_automation_connection, account: board.account, kanban_board: board)
    rule = create(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      event_name: Events::Types::KANBAN_CARD_WEBHOOK_RECEIVED
    )

    expect do
      described_class.new(connection: connection, card_id: card.id, event_key: 'n8n-123').perform!
    end.to have_enqueued_job(KanbanAutomations::ExecuteRuleJob)
      .with(rule.id, Events::Types::KANBAN_CARD_WEBHOOK_RECEIVED, 'n8n-123', card.id)
      .on_queue('critical')
  end

  it 'rejects an opportunity outside the connection board' do
    connection = create(:kanban_automation_connection)
    outside_card = create(:kanban_card)

    expect do
      described_class.new(connection: connection, card_id: outside_card.id, event_key: 'n8n-123').perform!
    end.to raise_error(ActiveRecord::RecordNotFound)
  end
end
