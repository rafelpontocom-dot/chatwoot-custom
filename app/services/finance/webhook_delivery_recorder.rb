require 'digest'

class Finance::WebhookDeliveryRecorder
  def initialize(connection:, raw_payload:, payload: nil)
    @connection = connection
    @raw_payload = raw_payload
    @payload = payload&.with_indifferent_access
  end

  def perform
    delivery = find_or_initialize_delivery
    delivery.assign_attributes(
      account: @connection.account,
      payload_digest: payload_digest,
      raw_payload: @raw_payload,
      received_at: delivery.received_at || Time.current
    )
    delivery.save!
    delivery
  end

  private

  def find_or_initialize_delivery
    return @connection.finance_webhook_deliveries.find_or_initialize_by(payload_digest: payload_digest) if provider_event_id.blank?

    @connection.finance_webhook_deliveries.find_or_initialize_by(provider_event_id: provider_event_id)
  end

  def provider_event_id
    @payload&.fetch(:id, nil)
  end

  def payload_digest
    Digest::SHA256.hexdigest(@raw_payload)
  end
end
