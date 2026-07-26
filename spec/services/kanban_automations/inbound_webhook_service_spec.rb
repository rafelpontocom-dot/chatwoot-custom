require 'rails_helper'

RSpec.describe KanbanAutomations::InboundWebhookService do
  it 'starts webhook rules scoped to the approved connection' do
    board = create(:kanban_board)
    card = create(:kanban_card, account: board.account, kanban_board: board)
    connection = create(:kanban_automation_connection, account: board.account, kanban_board: board)
    rule = create(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      event_name: Events::Types::KANBAN_CARD_WEBHOOK_RECEIVED,
      conditions: { connection_ids: [connection.id] }
    )

    expect do
      described_class.new(connection: connection, card_id: card.id, event_key: 'n8n-123').perform!
    end.to have_enqueued_job(KanbanAutomations::ExecuteRuleJob)
      .with(
        rule.id,
        Events::Types::KANBAN_CARD_WEBHOOK_RECEIVED,
        'n8n-123',
        card.id,
        { event_data: { connection_id: connection.id } }
      )
      .on_queue('critical')
  end

  it 'does not start a rule attached to another connection' do
    board = create(:kanban_board)
    card = create(:kanban_card, account: board.account, kanban_board: board)
    connection = create(:kanban_automation_connection, account: board.account, kanban_board: board)
    other_connection = create(:kanban_automation_connection, account: board.account, kanban_board: board)
    create(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      event_name: Events::Types::KANBAN_CARD_WEBHOOK_RECEIVED,
      conditions: { connection_ids: [other_connection.id] }
    )

    expect do
      described_class.new(connection: connection, card_id: card.id, event_key: 'n8n-123').perform!
    end.not_to have_enqueued_job(KanbanAutomations::ExecuteRuleJob)
  end

  it 'rejects an opportunity outside the connection board' do
    connection = create(:kanban_automation_connection)
    outside_card = create(:kanban_card)

    expect do
      described_class.new(connection: connection, card_id: outside_card.id, event_key: 'n8n-123').perform!
    end.to raise_error(ActiveRecord::RecordNotFound)
  end
end
