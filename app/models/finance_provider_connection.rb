# == Schema Information
#
# Table name: finance_provider_connections
#
#  id                  :bigint           not null, primary key
#  api_key             :string
#  display_name        :string
#  environment         :string           default("sandbox"), not null
#  last_error          :text
#  last_verified_at    :datetime
#  last_webhook_at     :datetime
#  lock_version        :integer          default(0), not null
#  provider            :string           not null
#  settings            :jsonb            not null
#  status              :string           default("disconnected"), not null
#  webhook_token       :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#  provider_account_id :string
#
# Indexes
#
#  index_finance_provider_connections_on_account_id               (account_id)
#  index_finance_provider_connections_on_account_id_and_provider  (account_id,provider) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class FinanceProviderConnection < ApplicationRecord
  ENVIRONMENTS = %w[sandbox production].freeze
  STATUSES = %w[disconnected pending connected attention error].freeze
  # Each ifthenpay payment method is enabled by its own merchant key (ITP-000000).
  # They live in settings because the dashboard needs to know which methods are on.
  IFTHENPAY_METHOD_KEYS = {
    'multibanco' => 'mb_key',
    'mbway' => 'mbway_key',
    'payshop' => 'payshop_key',
    'credit_card' => 'ccard_key'
  }.freeze

  belongs_to :account

  has_many :finance_customers, dependent: :restrict_with_exception
  has_many :finance_payments, dependent: :restrict_with_exception
  has_many :finance_payment_events, dependent: :restrict_with_exception
  has_many :finance_webhook_deliveries, dependent: :restrict_with_exception

  encrypts :api_key if Chatwoot.encryption_configured?
  encrypts :webhook_token if Chatwoot.encryption_configured?

  validates :provider, presence: true, uniqueness: { scope: :account_id }
  validates :environment, inclusion: { in: ENVIRONMENTS }
  validates :status, inclusion: { in: STATUSES }
  validates :api_key, presence: true, if: :credentials_required?
  validates :webhook_token, length: { in: 32..255 }, if: :asaas_webhook_token_present?
  validate :provider_available_for_account_market
  validate :ifthenpay_has_a_usable_method

  # The merchant key for a billing type, e.g. 'mbway' => 'ITP-000123'.
  def ifthenpay_method_key(billing_type)
    settings.to_h[IFTHENPAY_METHOD_KEYS[billing_type.to_s]].presence
  end

  def ifthenpay_enabled_billing_types
    IFTHENPAY_METHOD_KEYS.keys.select { |billing_type| ifthenpay_method_key(billing_type).present? }
  end

  def public_payload
    {
      id: id,
      provider: provider,
      environment: environment,
      provider_account_id: provider_account_id,
      display_name: display_name,
      status: status,
      last_error: last_error,
      last_verified_at: last_verified_at,
      last_webhook_at: last_webhook_at,
      settings: settings,
      lock_version: lock_version
    }.merge(provider == 'ifthenpay' ? { enabled_billing_types: ifthenpay_enabled_billing_types } : {})
  end

  private

  def credentials_required?
    provider != 'manual' && status.in?(%w[pending connected])
  end

  def asaas_webhook_token_present?
    provider == 'asaas' && webhook_token.present?
  end

  # A connection that cannot charge anything is a configuration mistake, not a
  # usable connection, so refuse it before it reaches the charge dialog.
  def ifthenpay_has_a_usable_method
    return unless provider == 'ifthenpay'
    return unless status.in?(%w[pending connected])
    return if ifthenpay_enabled_billing_types.any?

    errors.add(:settings, 'must contain at least one ifthenpay payment method key')
  end

  def provider_available_for_account_market
    market = account&.finance_module_setting&.market || 'BR'
    return if Finance::ProviderCatalog.available_for_market?(provider, market)

    errors.add(:provider, 'is not available for this account market')
  end
end
