# == Schema Information
#
# Table name: finance_payment_events
#
#  id                             :bigint           not null, primary key
#  error_message                  :text
#  event_type                     :string           not null
#  metadata                       :jsonb            not null
#  occurred_at                    :datetime         not null
#  processing_status              :string           default("processed"), not null
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  account_id                     :bigint           not null
#  actor_id                       :bigint
#  finance_payment_id             :bigint           not null
#  finance_provider_connection_id :bigint           not null
#  provider_event_id              :string
#
# Indexes
#
#  index_finance_payment_events_on_account_id                      (account_id)
#  index_finance_payment_events_on_actor_id                        (actor_id)
#  index_finance_payment_events_on_connection_and_provider_event
#    (finance_provider_connection_id,provider_event_id) UNIQUE WHERE (provider_event_id IS NOT NULL)
#  index_finance_payment_events_on_finance_payment_id              (finance_payment_id)
#  index_finance_payment_events_on_finance_provider_connection_id  (finance_provider_connection_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (actor_id => users.id)
#  fk_rails_...  (finance_payment_id => finance_payments.id)
#  fk_rails_...  (finance_provider_connection_id => finance_provider_connections.id)
#
class FinancePaymentEvent < ApplicationRecord
  PROCESSING_STATUSES = %w[processed ignored failed].freeze

  belongs_to :account
  belongs_to :finance_payment
  belongs_to :finance_provider_connection
  belongs_to :actor, class_name: 'User', optional: true

  validates :event_type, :occurred_at, presence: true
  validates :processing_status, inclusion: { in: PROCESSING_STATUSES }
  validates :provider_event_id, uniqueness: { scope: :finance_provider_connection_id }, allow_nil: true
  validate :references_belong_to_account

  def public_payload
    {
      id: id,
      event_type: event_type,
      occurred_at: occurred_at,
      processing_status: processing_status,
      error_message: error_message,
      actor: actor && { id: actor.id, name: actor.name }
    }
  end

  private

  def references_belong_to_account
    %i[finance_payment finance_provider_connection].each do |reference|
      record = public_send(reference)
      next if record.blank? || record.account_id == account_id

      errors.add(reference, 'must belong to the account')
    end
  end
end
