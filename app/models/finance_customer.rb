# == Schema Information
#
# Table name: finance_customers
#
#  id                             :bigint           not null, primary key
#  last_synced_at                 :datetime
#  provider_payload               :jsonb            not null
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  account_id                     :bigint           not null
#  contact_id                     :bigint           not null
#  finance_provider_connection_id :bigint           not null
#  provider_customer_id           :string           not null
#
# Indexes
#
#  index_finance_customers_on_account_id                        (account_id)
#  index_finance_customers_on_connection_and_contact            (finance_provider_connection_id,contact_id) UNIQUE
#  index_finance_customers_on_connection_and_provider_customer  (finance_provider_connection_id,provider_customer_id) UNIQUE
#  index_finance_customers_on_contact_id                        (contact_id)
#  index_finance_customers_on_finance_provider_connection_id    (finance_provider_connection_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (finance_provider_connection_id => finance_provider_connections.id)
#
class FinanceCustomer < ApplicationRecord
  belongs_to :account
  belongs_to :contact
  belongs_to :finance_provider_connection

  has_many :finance_payments, dependent: :restrict_with_exception

  validates :provider_customer_id, presence: true, uniqueness: { scope: :finance_provider_connection_id }
  validates :contact_id, uniqueness: { scope: :finance_provider_connection_id }
  validate :references_belong_to_account

  private

  def references_belong_to_account
    validate_account_reference(:contact)
    validate_account_reference(:finance_provider_connection)
  end

  def validate_account_reference(reference)
    record = public_send(reference)
    return if record.blank? || record.account_id == account_id

    errors.add(reference, 'must belong to the account')
  end
end
