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
