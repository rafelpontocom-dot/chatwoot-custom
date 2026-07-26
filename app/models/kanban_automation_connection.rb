# == Schema Information
#
# Table name: kanban_automation_connections
#
#  id              :bigint           not null, primary key
#  active          :boolean          default(TRUE), not null
#  inbound_token   :string           not null
#  name            :string           not null
#  secret          :text             not null
#  webhook_url     :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  kanban_board_id :bigint           not null
#
# Indexes
#
#  idx_kanban_automation_connections_board_name            (kanban_board_id,name) UNIQUE
#  index_kanban_automation_connections_on_account_id       (account_id)
#  index_kanban_automation_connections_on_inbound_token    (inbound_token) UNIQUE
#  index_kanban_automation_connections_on_kanban_board_id  (kanban_board_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (kanban_board_id => kanban_boards.id)
#
class KanbanAutomationConnection < ApplicationRecord
  include WebhookSecretable

  has_secure_token :inbound_token

  belongs_to :account
  belongs_to :kanban_board
  has_many :kanban_automation_connection_audits, dependent: :nullify

  scope :active, -> { where(active: true) }

  validates :name, presence: true, uniqueness: { scope: :kanban_board_id }
  validates :webhook_url, presence: true
  validate :secure_webhook_url
  validate :board_belongs_to_account

  private

  def secure_webhook_url
    uri = URI.parse(webhook_url.to_s)
    return if uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.blank?

    errors.add(:webhook_url, 'must be a valid HTTPS URL without credentials')
  rescue URI::InvalidURIError
    errors.add(:webhook_url, 'must be a valid HTTPS URL without credentials')
  end

  def board_belongs_to_account
    return if account.blank? || kanban_board.blank?
    return if account_id == kanban_board.account_id

    errors.add(:kanban_board, :invalid)
  end
end
