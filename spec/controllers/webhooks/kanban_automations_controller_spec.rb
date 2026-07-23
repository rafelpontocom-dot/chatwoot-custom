require 'rails_helper'

RSpec.describe 'Kanban automation inbound webhook', type: :request do
  def webhook_url(connection)
    "/webhooks/kanban/#{connection.inbound_token}"
  end

  def headers_for(connection, body, timestamp: Time.current.to_i.to_s, event_key: 'n8n-event-123')
    signature = OpenSSL::HMAC.hexdigest('SHA256', connection.secret, "#{timestamp}.#{body}")
    {
      'CONTENT_TYPE' => 'application/json',
      'X-Chatwoot-Timestamp' => timestamp,
      'X-Chatwoot-Signature' => "sha256=#{signature}",
      'X-Chatwoot-Idempotency-Key' => event_key
    }
  end

  it 'accepts a signed event and enqueues matching workflow rules' do
    board = create(:kanban_board)
    card = create(:kanban_card, account: board.account, kanban_board: board)
    connection = create(:kanban_automation_connection, account: board.account, kanban_board: board)
    rule = create(
      :kanban_automation_rule,
      account: board.account,
      kanban_board: board,
      event_name: Events::Types::KANBAN_CARD_WEBHOOK_RECEIVED
    )
    body = { card_id: card.id }.to_json

    expect do
      post webhook_url(connection), params: body, headers: headers_for(connection, body)
    end.to have_enqueued_job(KanbanAutomations::ExecuteRuleJob)
      .with(rule.id, Events::Types::KANBAN_CARD_WEBHOOK_RECEIVED, 'n8n-event-123', card.id)
      .on_queue('critical')

    expect(response).to have_http_status(:accepted)
  end

  it 'rejects an unsigned request' do
    connection = create(:kanban_automation_connection)

    post webhook_url(connection), params: { card_id: 1 }.to_json, headers: { 'CONTENT_TYPE' => 'application/json' }

    expect(response).to have_http_status(:unauthorized)
  end

  it 'rejects a signed request without an idempotency key' do
    connection = create(:kanban_automation_connection)
    body = { card_id: 1 }.to_json
    headers = headers_for(connection, body).except('X-Chatwoot-Idempotency-Key')

    post webhook_url(connection), params: body, headers: headers

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'rejects a request with an expired signature timestamp' do
    connection = create(:kanban_automation_connection)
    body = { card_id: 1 }.to_json
    headers = headers_for(connection, body, timestamp: 6.minutes.ago.to_i.to_s)

    post webhook_url(connection), params: body, headers: headers

    expect(response).to have_http_status(:unauthorized)
  end
end
