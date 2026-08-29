# rubocop:disable Layout/LineLength
# == Schema Information
#
# Table name: finance_webhook_deliveries
#
#  id                             :bigint           not null, primary key
#  error_message                  :text
#  payload_digest                 :string           not null
#  processed_at                   :datetime
#  processing_status              :string           default("failed"), not null
#  raw_payload                    :text             not null
#  received_at                    :datetime         not null
#  retry_count                    :integer          default(0), not null
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  account_id                     :bigint           not null
#  finance_provider_connection_id :bigint           not null
#  provider_event_id              :string
#
# Indexes
#
#  idx_on_finance_provider_connection_id_58dd06212f           (finance_provider_connection_id)
#  index_finance_webhook_deliveries_for_connection_status     (finance_provider_connection_id,processing_status,received_at)
#  index_finance_webhook_deliveries_on_account_id             (account_id)
#  index_finance_webhook_deliveries_on_connection_and_digest  (finance_provider_connection_id,payload_digest) UNIQUE
#  index_finance_webhook_deliveries_on_connection_and_event   (finance_provider_connection_id,provider_event_id) UNIQUE WHERE (provider_event_id IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (finance_provider_connection_id => finance_provider_connections.id)
#
# rubocop:enable Layout/LineLength
class FinanceWebhookDelivery < ApplicationRecord
  PROCESSING_STATUSES = %w[processed ignored failed].freeze

  belongs_to :account
  belongs_to :finance_provider_connection

  encrypts :raw_payload if Chatwoot.encryption_configured?

  validates :payload_digest, :raw_payload, :received_at, presence: true
  validates :processing_status, inclusion: { in: PROCESSING_STATUSES }
  validates :provider_event_id, uniqueness: { scope: :finance_provider_connection_id }, allow_nil: true
  validates :payload_digest, uniqueness: { scope: :finance_provider_connection_id }
  validate :connection_belongs_to_account

  def public_payload
    {
      id: id,
      provider: finance_provider_connection.provider,
      provider_event_id: provider_event_id,
      processing_status: processing_status,
      error_message: error_message,
      received_at: received_at,
      processed_at: processed_at,
      retry_count: retry_count
    }
  end

  def mark_processed!(status:)
    update!(
      processing_status: status,
      error_message: nil,
      processed_at: Time.current
    )
  end

  def mark_failed!(error)
    update!(processing_status: 'failed', error_message: sanitized_error(error))
  end

  def increment_retry_count!
    update!(retry_count: retry_count + 1)
  end

  private

  def connection_belongs_to_account
    return if finance_provider_connection.blank? || finance_provider_connection.account_id == account_id

    errors.add(:finance_provider_connection, 'must belong to the account')
  end

  def sanitized_error(error)
    "Webhook processing failed: #{error.class.name}"
  end
end
