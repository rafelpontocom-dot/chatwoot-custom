# == Schema Information
#
# Table name: kanban_calendar_appointment_resources
#
#  id                             :bigint           not null, primary key
#  appointment_status             :string           not null
#  ends_at                        :datetime         not null
#  starts_at                      :datetime         not null
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  kanban_calendar_appointment_id :bigint           not null
#  kanban_calendar_resource_id    :bigint           not null
#
# Indexes
#
# rubocop:disable Layout/LineLength
#  exclude_calendar_resource_appointment_overlaps                (kanban_calendar_resource_id, tsrange(starts_at, ends_at, '[)'::text)) WHERE ((appointment_status)::text = ANY ((ARRAY['scheduled'::character varying, 'confirmed'::character varying, 'checked_in'::character varying])::text[])) USING gist
# rubocop:enable Layout/LineLength
#  index_calendar_appointment_resources_on_appointment_resource  (kanban_calendar_appointment_id,kanban_calendar_resource_id) UNIQUE
#  index_calendar_appointment_resources_on_resource_and_range    (kanban_calendar_resource_id,starts_at,ends_at)
#
# Foreign Keys
#
#  fk_rails_...  (kanban_calendar_appointment_id => kanban_calendar_appointments.id)
#  fk_rails_...  (kanban_calendar_resource_id => kanban_calendar_resources.id)
#
class KanbanCalendarAppointmentResource < ApplicationRecord
  belongs_to :kanban_calendar_appointment
  belongs_to :kanban_calendar_resource

  validates :appointment_status, inclusion: { in: KanbanCalendarAppointment::STATUSES }
  validates :starts_at, :ends_at, presence: true
  validate :ends_after_starts
  validate :resource_belongs_to_appointment_account

  private

  def ends_after_starts
    return if starts_at.blank? || ends_at.blank? || ends_at > starts_at

    errors.add(:ends_at, 'must be after starts at')
  end

  def resource_belongs_to_appointment_account
    return if kanban_calendar_resource.blank? || kanban_calendar_appointment.blank?
    return if kanban_calendar_resource.account_id == kanban_calendar_appointment.account_id

    errors.add(:kanban_calendar_resource, 'must belong to the appointment account')
  end
end
