# == Schema Information
#
# Table name: marketing_module_settings
#
#  id             :bigint           not null, primary key
#  disabled_at    :datetime
#  enabled        :boolean          default(FALSE), not null
#  enabled_at     :datetime
#  lock_version   :integer          default(0), not null
#  settings       :jsonb            not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  account_id     :bigint           not null
#  disabled_by_id :bigint
#  enabled_by_id  :bigint
#
# Indexes
#
#  index_marketing_module_settings_on_account_id      (account_id) UNIQUE
#  index_marketing_module_settings_on_disabled_by_id  (disabled_by_id)
#  index_marketing_module_settings_on_enabled_by_id   (enabled_by_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (disabled_by_id => users.id)
#  fk_rails_...  (enabled_by_id => users.id)
#
class MarketingModuleSetting < ApplicationRecord
  belongs_to :account
  belongs_to :enabled_by, class_name: 'User', optional: true
  belongs_to :disabled_by, class_name: 'User', optional: true

  validates :account_id, uniqueness: true

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
      settings: settings,
      enabled_at: enabled_at,
      disabled_at: disabled_at,
      lock_version: lock_version
    }
  end
end
