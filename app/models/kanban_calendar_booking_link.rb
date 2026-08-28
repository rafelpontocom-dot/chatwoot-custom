# == Schema Information
#
# Table name: kanban_calendar_booking_links
#
#  id                              :bigint           not null, primary key
#  active                          :boolean          default(TRUE), not null
#  expires_at                      :datetime
#  max_uses                        :integer
#  token                           :string           not null
#  uses_count                      :integer          default(0), not null
#  created_at                      :datetime         not null
#  updated_at                      :datetime         not null
#  account_id                      :bigint           not null
#  kanban_calendar_booking_page_id :bigint           not null
#  kanban_calendar_procedure_id    :bigint
#
# Indexes
#
#  idx_on_kanban_calendar_procedure_id_e0a8311a49     (kanban_calendar_procedure_id)
#  index_calendar_booking_links_on_page_id            (kanban_calendar_booking_page_id)
#  index_kanban_calendar_booking_links_on_account_id  (account_id)
#  index_kanban_calendar_booking_links_on_token       (token) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (kanban_calendar_booking_page_id => kanban_calendar_booking_pages.id)
#  fk_rails_...  (kanban_calendar_procedure_id => kanban_calendar_procedures.id)
#
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
