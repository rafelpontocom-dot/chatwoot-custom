# == Schema Information
#
# Table name: raevo_ai_commands
#
#  id                      :bigint           not null, primary key
#  command_type            :string           not null
#  payload_digest          :string           not null
#  result                  :jsonb            not null
#  state                   :string           default("claimed"), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  action_id               :string           not null
#  raevo_ai_integration_id :bigint           not null
#
# Indexes
#
#  idx_raevo_ai_commands_on_integration_and_action  (raevo_ai_integration_id,action_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (raevo_ai_integration_id => raevo_ai_integrations.id)
#
class RaevoAiCommand < ApplicationRecord
  STATES = %w[claimed applied failed_retryable failed_terminal unknown].freeze

  belongs_to :raevo_ai_integration

  validates :action_id, :command_type, :payload_digest, :state, presence: true
  validates :state, inclusion: { in: STATES }
end
