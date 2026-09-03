# == Schema Information
#
# Table name: marketing_provider_connections
#
#  id                  :bigint           not null, primary key
#  access_token        :text
#  display_name        :string
#  expires_at          :datetime
#  last_error          :string
#  last_verified_at    :datetime
#  lock_version        :integer          default(0), not null
#  provider            :string           not null
#  settings            :jsonb            not null
#  status              :string           default("disconnected"), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#  external_account_id :string           not null
#
# Indexes
#
#  index_marketing_connections_on_account_provider_and_external  (account_id,provider,external_account_id) UNIQUE
#  index_marketing_provider_connections_on_account_id            (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class MarketingProviderConnection < ApplicationRecord
  PROVIDERS = %w[meta google tiktok].freeze
  STATUSES = %w[disconnected pending connected attention error].freeze

  # O token de pagina do Meta abre a caixa de leads de um anunciante.
  encrypts :access_token if Chatwoot.encryption_configured?

  belongs_to :account
  has_many :marketing_lead_forms, dependent: :destroy

  validates :provider, inclusion: { in: PROVIDERS }
  validates :status, inclusion: { in: STATUSES }
  validates :external_account_id, presence: true, uniqueness: { scope: [:account_id, :provider] }

  scope :connected, -> { where(status: 'connected') }

  def status_connected?
    status == 'connected'
  end

  # O Meta nao emite refresh token: troca-se por um de longa duracao, de uns 60
  # dias. Expirar em silencio e parar de receber lead por uma semana e o modo de
  # falha realista, entao avisamos com folga.
  RENEWAL_WINDOW = 7.days

  def token_expired?
    expires_at.present? && expires_at <= Time.current
  end

  def token_expiring?
    expires_at.present? && expires_at <= RENEWAL_WINDOW.from_now
  end

  # Nunca o texto do provedor no erro guardado: so a classe, para nao vazar
  # detalhe de conta alheia num painel.
  def mark_attention!(error)
    update!(status: 'attention', last_error: error.is_a?(String) ? error : error.class.name)
  end

  def public_payload
    {
      id: id,
      provider: provider,
      external_account_id: external_account_id,
      display_name: display_name,
      status: status,
      token_expiring: token_expiring?,
      expires_at: expires_at,
      last_error: last_error,
      last_verified_at: last_verified_at,
      pages: settings['pages'] || []
    }
  end
end
