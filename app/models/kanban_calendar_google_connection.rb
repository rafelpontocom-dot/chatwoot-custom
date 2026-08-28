# == Schema Information
#
# Table name: kanban_calendar_google_connections
#
#  id                          :bigint           not null, primary key
#  access_token                :string
#  expires_at                  :datetime
#  last_error                  :text
#  last_synced_at              :datetime
#  refresh_token               :string
#  status                      :string           default("disconnected"), not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  account_id                  :bigint           not null
#  calendar_id                 :string           default("primary"), not null
#  kanban_calendar_resource_id :bigint           not null
#
# Indexes
#
#  idx_on_kanban_calendar_resource_id_82d8f650ee           (kanban_calendar_resource_id) UNIQUE
#  index_kanban_calendar_google_connections_on_account_id  (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (kanban_calendar_resource_id => kanban_calendar_resources.id)
#
class KanbanCalendarGoogleConnection < ApplicationRecord
  STATUSES = %w[connected disconnected error].freeze

  belongs_to :account
  belongs_to :kanban_calendar_resource

  encrypts :access_token if Chatwoot.encryption_configured?
  encrypts :refresh_token if Chatwoot.encryption_configured?

  validates :calendar_id, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :kanban_calendar_resource_id, uniqueness: true
  validates :access_token, :refresh_token, :expires_at, presence: true, if: :connected?
  validate :resource_belongs_to_account

  def connected?
    status == 'connected'
  end

  def token_expired?
    expires_at.blank? || expires_at <= 5.minutes.from_now
  end

  private

  def resource_belongs_to_account
    return if kanban_calendar_resource.blank? || kanban_calendar_resource.account_id == account_id

    errors.add(:kanban_calendar_resource, 'must belong to the account')
  end
end
