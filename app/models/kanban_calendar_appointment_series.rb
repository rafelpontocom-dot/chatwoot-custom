# == Schema Information
#
# Table name: kanban_calendar_appointment_series
#
#  id                           :bigint           not null, primary key
#  ended_at                     :datetime
#  interval_days                :integer
#  interval_kind                :string           default("once"), not null
#  lock_version                 :integer          default(0), not null
#  metadata                     :jsonb            not null
#  planned_count                :integer          default(1), not null
#  started_at                   :datetime         not null
#  status                       :string           default("active"), not null
#  timezone                     :string           not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  account_id                   :bigint           not null
#  contact_id                   :bigint           not null
#  kanban_calendar_procedure_id :bigint           not null
#  kanban_card_id               :bigint
#
# Indexes
#
#  index_calendar_appointment_series_on_account_contact_status  (account_id,contact_id,status)
#  index_kanban_calendar_appointment_series_on_account_id       (account_id)
#  index_kanban_calendar_appointment_series_on_contact_id       (contact_id)
#  index_kanban_calendar_appointment_series_on_kanban_card_id   (kanban_card_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (kanban_calendar_procedure_id => kanban_calendar_procedures.id)
#  fk_rails_...  (kanban_card_id => kanban_cards.id)
#
class KanbanCalendarAppointmentSeries < ApplicationRecord
  STATUSES = %w[active completed canceled].freeze
  INTERVAL_KINDS = %w[once weekly biweekly monthly days].freeze

  belongs_to :account
  belongs_to :contact
  belongs_to :kanban_card, optional: true
  belongs_to :kanban_calendar_procedure

  has_many :kanban_calendar_appointments, dependent: :restrict_with_error

  validates :status, inclusion: { in: STATUSES }
  validates :interval_kind, inclusion: { in: INTERVAL_KINDS }
  validates :planned_count, numericality: { only_integer: true, in: 1..100 }
  validates :timezone, presence: true
  validates :interval_days, numericality: { only_integer: true, greater_than: 0 }, if: :days_interval?
  validate :interval_days_absent_for_other_intervals
  validate :account_matches_related_records

  private

  def days_interval?
    interval_kind == 'days'
  end

  def interval_days_absent_for_other_intervals
    return if days_interval? || interval_days.blank?

    errors.add(:interval_days, 'must be blank unless interval kind is days')
  end

  def account_matches_related_records
    account_scoped_records.each do |association, record|
      errors.add(association, 'must belong to the account') if record && record.account_id != account_id
    end
  end

  def account_scoped_records
    {
      contact: contact,
      kanban_calendar_procedure: kanban_calendar_procedure,
      kanban_card: kanban_card
    }
  end
end
