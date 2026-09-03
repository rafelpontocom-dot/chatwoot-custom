# == Schema Information
#
# Table name: marketing_webhook_deliveries
#
#  id                :bigint           not null, primary key
#  error_message     :text
#  payload_digest    :string           not null
#  processed_at      :datetime
#  processing_status :string           default("failed"), not null
#  provider          :string           default("meta"), not null
#  raw_payload       :text             not null
#  received_at       :datetime         not null
#  retry_count       :integer          default(0), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint           not null
#  provider_event_id :string
#
# Indexes
#
#  index_marketing_deliveries_for_account_status     (account_id,processing_status,received_at)
#  index_marketing_deliveries_on_account_and_digest  (account_id,payload_digest) UNIQUE
#  index_marketing_deliveries_on_account_and_event   (account_id,provider_event_id) UNIQUE WHERE (provider_event_id IS NOT NULL)
#  index_marketing_webhook_deliveries_on_account_id  (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class MarketingWebhookDelivery < ApplicationRecord
  PROCESSING_STATUSES = %w[processed ignored failed].freeze

  # O corpo cru do Meta traz nome e telefone de paciente.
  encrypts :raw_payload if Chatwoot.encryption_configured?

  belongs_to :account

  validates :processing_status, inclusion: { in: PROCESSING_STATUSES }
  validates :payload_digest, presence: true, uniqueness: { scope: :account_id }

  def mark_processed!(status: 'processed')
    update!(processing_status: status, processed_at: Time.current, error_message: nil)
  end

  # So a classe do erro: o texto do provedor pode carregar id de conta alheia.
  def mark_failed!(error)
    update!(processing_status: 'failed', error_message: "Webhook processing failed: #{error.class.name}")
  end

  def public_payload
    {
      id: id, provider: provider, provider_event_id: provider_event_id,
      processing_status: processing_status, error_message: error_message,
      received_at: received_at, processed_at: processed_at, retry_count: retry_count
    }
  end
end
