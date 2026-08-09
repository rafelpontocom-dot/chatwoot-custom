class KanbanCalendarBookingLink < ApplicationRecord
  belongs_to :account
  belongs_to :kanban_calendar_booking_page
  belongs_to :kanban_calendar_procedure, optional: true

  before_validation :ensure_token

  validates :token, presence: true, uniqueness: true
  validates :max_uses, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :references_belong_to_account

  def available?
    active? && (expires_at.blank? || expires_at.future?) && (max_uses.blank? || uses_count < max_uses)
  end

  def consume!
    with_lock do
      raise ActiveRecord::RecordInvalid, self unless available?

      self.uses_count += 1
      save!
    end
  end

  private

  def ensure_token
    self.token ||= SecureRandom.urlsafe_base64(24)
  end

  def references_belong_to_account
    records = [kanban_calendar_booking_page, kanban_calendar_procedure].compact
    return if records.all? { |record| record.account_id == account_id }

    errors.add(:base, 'Booking link references must belong to the account')
  end
end
