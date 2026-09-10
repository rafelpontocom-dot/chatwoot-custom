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

  # Os oito comandos que a Elis sabe executar. A lista existe para o tipo deixar
  # de ser texto livre: sem ela, o que chegasse da ponte era gravado como viesse
  # e depois devolvido cru ao ecrã da clínica.
  #
  # O preço é acoplamento assumido: acrescentar um comando no runtime obriga a
  # acrescentá-lo aqui, senão a gravação é recusada. É de propósito — preferimos
  # a recusa barulhenta a um comando que ninguém sabe o que faz.
  COMMAND_TYPES = %w[
    calendar.book_appointment
    crm.add_label
    crm.ensure_opportunity
    crm.move_stage
    crm.update_contact_name
    crm.update_fields
    finance.create_charge
    handoff.apply
  ].freeze

  belongs_to :raevo_ai_integration

  validates :action_id, :command_type, :payload_digest, :state, presence: true
  validates :state, inclusion: { in: STATES }
  validates :command_type, inclusion: { in: COMMAND_TYPES }
end
