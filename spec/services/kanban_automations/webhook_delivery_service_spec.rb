require 'rails_helper'

RSpec.describe KanbanAutomations::WebhookDeliveryService do
  it 'posts a signed payload with an idempotency key and no redirects' do
    board = create(:kanban_board)
    card = create(:kanban_card, account: board.account, kanban_board: board)
    connection = create(
      :kanban_automation_connection,
      account: board.account,
      kanban_board: board,
      webhook_url: 'https://automacao.example.test/hooks/opportunity'
    )
    rule = create(:kanban_automation_rule, account: board.account, kanban_board: board)
    execution = create(
      :kanban_automation_execution,
      account: board.account,
      kanban_automation_rule: rule,
      kanban_card: card,
      event_name: Events::Types::KANBAN_CARD_STAGE_CHANGED,
      event_key: 'event-123'
    )
    response = Net::HTTPCreated.new('1.1', '201', 'Created')
    captured = {}
    allow(SsrfFilter).to receive(:post) do |url, **options|
      captured[:url] = url
      captured.merge!(options)
      response
    end

    result = described_class.new(
      execution: execution,
      rule: rule,
      card: card,
      node: { id: 'webhook', data: { connection_id: connection.id } }
    ).perform!

    timestamp = captured[:headers]['X-Chatwoot-Timestamp']
    expected_signature = OpenSSL::HMAC.hexdigest('SHA256', connection.secret, "#{timestamp}.#{captured[:body]}")

    expect(result).to include('status' => 'succeeded', 'connection_id' => connection.id, 'status_code' => 201)
    expect(captured).to include(
      url: connection.webhook_url,
      max_redirects: 0,
      allow_unfollowed_redirects: true
    )
    expect(captured[:headers]).to include(
      'X-Chatwoot-Event' => Events::Types::KANBAN_CARD_STAGE_CHANGED,
      'X-Chatwoot-Idempotency-Key' => "kanban-#{execution.id}-webhook",
      'X-Chatwoot-Signature' => "sha256=#{expected_signature}"
    )
    expect(captured[:body]).not_to include(connection.secret)
  end
end
