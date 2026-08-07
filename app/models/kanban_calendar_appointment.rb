# == Schema Information
#
# Table name: kanban_calendar_appointments
#
#  id                                    :bigint           not null, primary key
#  appointment_version                   :integer          default(1), not null
#  canceled_at                           :datetime
#  cancellation_reason                   :string
#  completed_at                          :datetime
#  ends_at                               :datetime         not null
#  external_refs                         :jsonb            not null
#  lock_version                          :integer          default(0), not null
#  no_show_at                            :datetime
#  notes                                 :text
#  occurrence_number                     :integer          default(1), not null
#  starts_at                             :datetime         not null
#  status                                :string           default("scheduled"), not null
#  timezone                              :string           not null
#  created_at                            :datetime         not null
#  updated_at                            :datetime         not null
#  account_id                            :bigint           not null
#  canceled_by_id                        :bigint
#  contact_id                            :bigint           not null
#  kanban_calendar_appointment_series_id :bigint           not null
#  kanban_calendar_procedure_id          :bigint           not null
#  kanban_card_id                        :bigint
#  rescheduled_from_id                   :bigint
#
# Indexes
#
#  index_calendar_appointments_on_account_starts_status       (account_id,starts_at,status)
#  index_calendar_appointments_on_series_and_occurrence       (kanban_calendar_appointment_series_id,occurrence_number) UNIQUE
#  index_kanban_calendar_appointments_on_account_id           (account_id)
#  index_kanban_calendar_appointments_on_canceled_by_id       (canceled_by_id)
#  index_kanban_calendar_appointments_on_contact_id           (contact_id)
#  index_kanban_calendar_appointments_on_kanban_card_id       (kanban_card_id)
#  index_kanban_calendar_appointments_on_rescheduled_from_id  (rescheduled_from_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (canceled_by_id => users.id)
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (kanban_calendar_appointment_series_id => kanban_calendar_appointment_series.id)
#  fk_rails_...  (kanban_calendar_procedure_id => kanban_calendar_procedures.id)
#  fk_rails_...  (kanban_card_id => kanban_cards.id)
#  fk_rails_...  (rescheduled_from_id => kanban_calendar_appointments.id)
#
class KanbanCalendarAppointment < ApplicationRecord
  ACTIVE_STATUSES = %w[scheduled confirmed checked_in].freeze
  STATUSES = (ACTIVE_STATUSES + %w[completed no_show canceled]).freeze

  belongs_to :account
  belongs_to :kanban_calendar_appointment_series
  belongs_to :contact
  belongs_to :kanban_card, optional: true
  belongs_to :kanban_calendar_procedure
  belongs_to :rescheduled_from, class_name: 'KanbanCalendarAppointment', optional: true
  belongs_to :canceled_by, class_name: 'User', optional: true

  has_many :kanban_calendar_appointment_resources, dependent: :restrict_with_error
  has_many :kanban_calendar_resources, through: :kanban_calendar_appointment_resources
  has_many :kanban_calendar_appointment_events, dependent: :restrict_with_error

  validates :status, inclusion: { in: STATUSES }
  validates :starts_at, :ends_at, :timezone, presence: true
  validates :occurrence_number, :appointment_version, numericality: { only_integer: true, greater_than: 0 }
  validate :ends_after_starts
  validate :account_matches_related_records

  scope :active, -> { where(status: ACTIVE_STATUSES) }
  scope :within, lambda { |starts_at, ends_at|
    where('kanban_calendar_appointments.starts_at < ? AND kanban_calendar_appointments.ends_at > ?', ends_at, starts_at)
  }

  def active_for_conflict?
    status.in?(ACTIVE_STATUSES)
  end

  private

  def ends_after_starts
    return if starts_at.blank? || ends_at.blank? || ends_at > starts_at

    errors.add(:ends_at, 'must be after starts at')
  end

  def account_matches_related_records
    account_scoped_records.each do |association, record|
      errors.add(association, 'must belong to the account') if record && record.account_id != account_id
    end
  end

  def account_scoped_records
    {
      kanban_calendar_appointment_series: kanban_calendar_appointment_series,
      contact: contact,
      kanban_calendar_procedure: kanban_calendar_procedure,
      kanban_card: kanban_card
    }
  end
end
