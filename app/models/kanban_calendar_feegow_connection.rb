# == Schema Information
#
# Table name: kanban_calendar_feegow_connections
#
#  id               :bigint           not null, primary key
#  api_token        :string
#  api_url          :string           default("https://api.feegow.com/v1/api"), not null
#  last_error       :text
#  last_imported_at :datetime
#  status           :string           default("disconnected"), not null
#  token_expires_at :datetime
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :bigint           not null
#
# Indexes
#
#  index_kanban_calendar_feegow_connections_on_account_id  (account_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
# A ligação da clínica ao Feegow. O token do Feegow vence a cada 90 dias — a
# validade fica gravada e à vista, porque sem aviso a agenda deixa de
# sincronizar em silêncio e ninguém descobre até marcar em cima de alguém.
class KanbanCalendarFeegowConnection < ApplicationRecord
  STATUSES = %w[connected disconnected error].freeze
  DEFAULT_TOKEN_LIFETIME = 90.days
  EXPIRY_WARNING_WINDOW = 14.days

  belongs_to :account

  encrypts :api_token if Chatwoot.encryption_configured?

  validates :api_url, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :api_token, presence: true, if: :connected?

  def connected?
    status == 'connected'
  end

  def token_expired?
    token_expires_at.present? && token_expires_at <= Time.current
  end

  def token_expiring_soon?
    token_expires_at.present? && !token_expired? && token_expires_at <= EXPIRY_WARNING_WINDOW.from_now
  end
end
