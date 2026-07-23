class KanbanAutomations::WebhookDeliveryService
  OPEN_TIMEOUT = 3
  READ_TIMEOUT = 10

  def initialize(execution:, rule:, card:, node:)
    @execution = execution
    @rule = rule
    @card = card
    @node = node.to_h.deep_stringify_keys
  end

  def perform!
    response = SsrfFilter.post(
      connection.webhook_url,
      body: body,
      headers: headers,
      max_redirects: 0,
      allow_unfollowed_redirects: true,
      http_options: { open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT }
    )
    raise SafeFetch::HttpError, "#{response.code} #{response.message}" unless response.is_a?(Net::HTTPSuccess)

    result('succeeded', status_code: response.code.to_i)
  rescue SsrfFilter::Error, Net::OpenTimeout, Net::ReadTimeout, SocketError, OpenSSL::SSL::SSLError => e
    raise KanbanAutomations::WebhookDeliveryError, e.message
  end

  private

  attr_reader :execution, :rule, :card, :node

  def connection
    @connection ||= rule.kanban_board.kanban_automation_connections.active.find(node.dig('data', 'connection_id'))
  end

  def body
    @body ||= payload.to_json
  end

  def headers
    timestamp = Time.current.to_i.to_s
    {
      'Content-Type' => 'application/json',
      'Accept' => 'application/json',
      'X-Chatwoot-Event' => execution.event_name,
      'X-Chatwoot-Delivery' => delivery_id,
      'X-Chatwoot-Idempotency-Key' => delivery_id,
      'X-Chatwoot-Timestamp' => timestamp,
      'X-Chatwoot-Signature' => "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', connection.secret, "#{timestamp}.#{body}")}"
    }
  end

  def delivery_id
    "kanban-#{execution.id}-#{node.fetch('id')}"
  end

  def payload
    {
      version: '1.0',
      event: execution.event_name,
      event_key: execution.event_key,
      occurred_at: Time.current.iso8601,
      automation: automation_payload,
      opportunity: opportunity_payload,
      contact: contact_payload,
      conversation: conversation_payload
    }
  end

  def automation_payload
    { rule_id: rule.id, rule_name: rule.name, execution_id: execution.id, node_id: node.fetch('id') }
  end

  def opportunity_payload
    {
      id: card.id,
      subject: card.subject,
      stage_id: card.kanban_stage_id,
      owner_id: card.owner_id,
      amount_cents: card.amount_cents,
      amount_currency: card.amount_currency,
      custom_fields: card.custom_field_values
    }
  end

  def contact_payload
    { id: card.contact_id, name: card.contact.name, email: card.contact.email, phone_number: card.contact.phone_number }
  end

  def conversation_payload
    return if card.conversation.blank?

    { id: card.conversation_id, inbox_id: card.inbox_id, status: card.conversation.status }
  end

  def result(status, details = {})
    {
      'action_name' => 'webhook',
      'status' => status,
      'connection_id' => connection.id,
      'delivery_id' => delivery_id
    }.merge(details.stringify_keys)
  end
end
