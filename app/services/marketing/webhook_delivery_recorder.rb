require 'digest'

class Marketing::WebhookDeliveryRecorder
  # Grava antes de processar: se a ingestao falhar, ainda se sabe que chegou.
  def initialize(account:, raw_payload:, provider_event_id: nil, provider: 'meta')
    @account = account
    @raw_payload = raw_payload
    @provider_event_id = provider_event_id
    @provider = provider
  end

  def perform
    delivery = find_or_initialize
    delivery.assign_attributes(
      account: account, provider: provider, payload_digest: payload_digest,
      raw_payload: raw_payload, received_at: delivery.received_at || Time.current
    )
    delivery.save!
    delivery
  end

  private

  attr_reader :account, :raw_payload, :provider_event_id, :provider

  # Pelo id do evento quando ha um; pelo corpo quando nao ha.
  def find_or_initialize
    return account.marketing_webhook_deliveries.find_or_initialize_by(payload_digest: payload_digest) if provider_event_id.blank?

    account.marketing_webhook_deliveries.find_or_initialize_by(provider_event_id: provider_event_id) do |delivery|
      delivery.payload_digest = payload_digest
    end
  end

  def payload_digest
    @payload_digest ||= Digest::SHA256.hexdigest(raw_payload.to_s)
  end
end
