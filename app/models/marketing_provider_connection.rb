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
#  page_tokens         :text
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
  encrypts :page_tokens if Chatwoot.encryption_configured?

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

  # Nunca o texto cru do provedor: de um erro do Meta guardamos a mensagem que
  # o GraphClient ja reduziu a tipo e codigo — e o que permite diagnosticar
  # depois — e de qualquer outra excecao, so a classe.
  def mark_attention!(error)
    detail = case error
             when String then error
             when Marketing::Meta::ApiError then error.message
             else error.class.name
             end
    update!(status: 'attention', last_error: detail)
  end

  # Token de pagina obtido de um token de usuario de longa duracao nao expira.
  # Por isso ele mora no banco, cifrado, e nao num cache de 24h: guardado, a
  # chegada de leads sobrevive aos 60 dias do token de usuario, que e o unico
  # que morre. O que exige token de usuario vivo passa a ser so descobrir
  # pagina e formulario novos.
  def page_token(page_id)
    stored_page_tokens[page_id.to_s].presence
  end

  def store_page_tokens!(tokens)
    update!(page_tokens: stored_page_tokens.merge(tokens).to_json)
  end

  def stored_page_tokens
    JSON.parse(page_tokens.presence || '{}')
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
