# == Schema Information
#
# Table name: raevo_ai_integrations
#
#  id         :bigint           not null, primary key
#  enabled    :boolean          default(FALSE), not null
#  settings   :jsonb            not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#  clinic_id  :string           not null
#
# Indexes
#
#  index_raevo_ai_integrations_on_account_id  (account_id) UNIQUE
#  index_raevo_ai_integrations_on_clinic_id   (clinic_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class RaevoAiIntegration < ApplicationRecord
  belongs_to :account
  has_many :raevo_ai_commands, inverse_of: :raevo_ai_integration, dependent: :restrict_with_error

  validates :account_id, uniqueness: true
  validates :clinic_id, presence: true, uniqueness: true
end
