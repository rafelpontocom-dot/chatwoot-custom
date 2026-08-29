# == Schema Information
#
# Table name: finance_payments
#
#  id                             :bigint           not null, primary key
#  amount_cents                   :integer          not null
#  billing_type                   :string           default("undefined"), not null
#  currency                       :string           default("BRL"), not null
#  description                    :text
#  due_on                         :date
#  external_reference             :string           not null
#  invoice_url                    :text
#  kind                           :string           default("charge"), not null
#  lock_version                   :integer          default(0), not null
#  paid_at                        :datetime
#  provider_payload               :jsonb            not null
#  status                         :string           default("draft"), not null
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  account_id                     :bigint           not null
#  contact_id                     :bigint           not null
#  finance_customer_id            :bigint
#  finance_provider_connection_id :bigint           not null
#  kanban_card_id                 :bigint
#  provider_customer_id           :string
#  provider_payment_id            :string
#
# Indexes
#
#  index_finance_payments_on_account_id                         (account_id)
#  index_finance_payments_on_account_id_and_external_reference  (account_id,external_reference) UNIQUE
#  index_finance_payments_on_account_id_and_kanban_card_id      (account_id,kanban_card_id)
#  index_finance_payments_on_account_id_and_status              (account_id,status)
#  index_finance_payments_on_connection_and_provider_payment
#    (finance_provider_connection_id,provider_payment_id) UNIQUE WHERE (provider_payment_id IS NOT NULL)
#  index_finance_payments_on_contact_id                         (contact_id)
#  index_finance_payments_on_finance_customer_id                (finance_customer_id)
#  index_finance_payments_on_finance_provider_connection_id     (finance_provider_connection_id)
#  index_finance_payments_on_kanban_card_id                     (kanban_card_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (finance_customer_id => finance_customers.id)
#  fk_rails_...  (finance_provider_connection_id => finance_provider_connections.id)
#  fk_rails_...  (kanban_card_id => kanban_cards.id)
#
class FinancePayment < ApplicationRecord
  BILLING_TYPES = %w[pix credit_card boleto undefined other].freeze
  KINDS = %w[charge checkout subscription installment].freeze
  STATUSES = %w[draft pending confirmed received overdue refunded chargeback canceled failed].freeze

  belongs_to :account
  belongs_to :contact
  belongs_to :kanban_card, optional: true
  belongs_to :finance_customer, optional: true
  belongs_to :finance_provider_connection

  has_many :finance_payment_events, dependent: :restrict_with_exception

  before_validation :assign_external_reference, on: :create

  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :billing_type, inclusion: { in: BILLING_TYPES }
  validates :currency, format: { with: /\A[A-Z]{3}\z/ }
  validates :external_reference, presence: true, uniqueness: { scope: :account_id }
  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validate :references_belong_to_account

  def public_payload
    {
      id: id,
      contact_id: contact_id,
      contact: contact_payload,
      kanban_card_id: kanban_card_id,
      kanban_card: kanban_card_payload,
      finance_provider_connection_id: finance_provider_connection_id,
      provider: finance_provider_connection.provider
    }.merge(payment_payload)
  end

  private

  def assign_external_reference
    self.external_reference ||= SecureRandom.uuid
  end

  def contact_payload
    {
      id: contact.id,
      name: contact.name,
      email: contact.email,
      phone_number: contact.phone_number
    }
  end

  def payment_payload
    attributes.slice(
      'provider_payment_id',
      'external_reference',
      'status',
      'billing_type',
      'amount_cents',
      'currency',
      'due_on',
      'paid_at',
      'invoice_url',
      'description',
      'created_at',
      'updated_at'
    ).symbolize_keys
  end

  def kanban_card_payload
    return unless kanban_card

    {
      id: kanban_card.id,
      subject: kanban_card.subject,
      conversation_id: kanban_card.conversation_id,
      owner: kanban_card.owner && { id: kanban_card.owner.id, name: kanban_card.owner.name }
    }
  end

  def references_belong_to_account
    %i[contact kanban_card finance_customer finance_provider_connection].each do |reference|
      record = public_send(reference)
      next if record.blank? || record.account_id == account_id

      errors.add(reference, 'must belong to the account')
    end
  end
end
