# == Schema Information
#
# Table name: kanban_calendar_appointment_events
#
#  id                             :bigint           not null, primary key
#  event_type                     :string           not null
#  metadata                       :jsonb            not null
#  occurred_at                    :datetime         not null
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  account_id                     :bigint           not null
#  actor_id                       :bigint
#  kanban_calendar_appointment_id :bigint           not null
#
# Indexes
#
#  index_calendar_appointment_events_on_appointment_and_time  (kanban_calendar_appointment_id,occurred_at)
#  index_kanban_calendar_appointment_events_on_account_id     (account_id)
#  index_kanban_calendar_appointment_events_on_actor_id       (actor_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (actor_id => users.id)
#  fk_rails_...  (kanban_calendar_appointment_id => kanban_calendar_appointments.id)
#
class KanbanCalendarAppointmentEvent < ApplicationRecord
  EVENT_TYPES = %w[created confirmed checked_in rescheduled canceled completed no_show series_split reminder_canceled external_sync].freeze

  belongs_to :account
  belongs_to :kanban_calendar_appointment
  belongs_to :actor, class_name: 'User', optional: true

  validates :event_type, inclusion: { in: EVENT_TYPES }
  validates :occurred_at, presence: true
  validate :account_matches_appointment

  private

  def account_matches_appointment
    return if kanban_calendar_appointment.blank? || kanban_calendar_appointment.account_id == account_id

    errors.add(:kanban_calendar_appointment, 'must belong to the account')
  end
end
