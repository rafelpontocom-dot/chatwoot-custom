# == Schema Information
#
# Table name: marketing_intake_sources
#
#  id               :bigint           not null, primary key
#  active           :boolean          default(TRUE), not null
#  crm_destination  :jsonb            not null
#  last_received_at :datetime
#  name             :string           not null
#  received_count   :integer          default(0), not null
#  token            :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :bigint           not null
#
# Indexes
#
#  index_marketing_intake_sources_on_account_id           (account_id)
#  index_marketing_intake_sources_on_account_id_and_name  (account_id,name) UNIQUE
#  index_marketing_intake_sources_on_token                (token) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class MarketingIntakeSource < ApplicationRecord
  # O token e a credencial de uma escrita publica: com ele se cria contato e
  # oportunidade. Vive cifrado, viaja em header (nunca na URL, que vaza por
  # Referer, log de proxy e historico de browser) e pode ser desligado na hora
  # pelo `active`.
  #
  # `deterministic` porque a autenticacao precisa procurar pelo valor.
  encrypts :token, deterministic: true if Chatwoot.encryption_configured?

  has_secure_token :token

  belongs_to :account

  validates :name, presence: true, uniqueness: { scope: :account_id }
  validate :destination_shape

  scope :active, -> { where(active: true) }

  def self.authenticate(token)
    return if token.blank?

    active.find_by(token: token)
  end

  def register_delivery!
    increment!(:received_count) # rubocop:disable Rails/SkipsModelValidations
    update_columns(last_received_at: Time.current, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

  # O token nunca sai daqui depois de criado; quem o perdeu gera outro.
  def public_payload(reveal_token: false)
    {
      id: id,
      name: name,
      active: active,
      crm_destination: crm_destination,
      last_received_at: last_received_at,
      received_count: received_count,
      created_at: created_at
    }.tap { |payload| payload[:token] = token if reveal_token }
  end

  private

  def destination_shape
    destination = crm_destination.to_h
    %w[kanban_board_id kanban_stage_id inbox_id].each do |key|
      errors.add(:crm_destination, "#{key} is required") if destination[key].blank?
    end
  end
end
