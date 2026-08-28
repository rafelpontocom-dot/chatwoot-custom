# == Schema Information
#
# Table name: finance_module_settings
#
#  id                         :bigint           not null, primary key
#  default_invoicing_provider :string
#  default_payment_provider   :string
#  disabled_at                :datetime
#  enabled                    :boolean          default(FALSE), not null
#  enabled_at                 :datetime
#  lock_version               :integer          default(0), not null
#  market                     :string           default("BR"), not null
#  settings                   :jsonb            not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  account_id                 :bigint           not null
#  disabled_by_id             :bigint
#  enabled_by_id              :bigint
#
# Indexes
#
#  index_finance_module_settings_on_account_id      (account_id) UNIQUE
#  index_finance_module_settings_on_disabled_by_id  (disabled_by_id)
#  index_finance_module_settings_on_enabled_by_id   (enabled_by_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (disabled_by_id => users.id)
#  fk_rails_...  (enabled_by_id => users.id)
#
class FinanceModuleSetting < ApplicationRecord
  MARKETS = %w[BR PT OTHER].freeze

  belongs_to :account
  belongs_to :enabled_by, class_name: 'User', optional: true
  belongs_to :disabled_by, class_name: 'User', optional: true

  validates :market, inclusion: { in: MARKETS }
  validates :account_id, uniqueness: true
  validate :default_providers_available_for_market

  def apply_enabled_state(actor:)
    return unless will_save_change_to_enabled?

    if enabled?
      self.enabled_at = Time.current
      self.enabled_by = actor
      self.disabled_at = nil
      self.disabled_by = nil
    else
      self.disabled_at = Time.current
      self.disabled_by = actor
    end
  end

  def public_payload
    {
      enabled: enabled,
      market: market,
      default_payment_provider: default_payment_provider,
      default_invoicing_provider: default_invoicing_provider,
      settings: settings,
      enabled_at: enabled_at,
      disabled_at: disabled_at,
      lock_version: lock_version
    }
  end

  private

  def default_providers_available_for_market
    validate_provider(:default_payment_provider, default_payment_provider)
    validate_provider(:default_invoicing_provider, default_invoicing_provider)
  end

  def validate_provider(attribute, provider)
    return if provider.blank? || Finance::ProviderCatalog.available_for_market?(provider, market)

    errors.add(attribute, 'is not available for this market')
  end
end
