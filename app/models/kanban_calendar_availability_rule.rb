# == Schema Information
#
# Table name: kanban_calendar_availability_rules
#
#  id                          :bigint           not null, primary key
#  active                      :boolean          default(TRUE), not null
#  date                        :date
#  ends_at_local               :time
#  kind                        :string           not null
#  starts_at_local             :time
#  weekday                     :integer
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  kanban_calendar_resource_id :bigint           not null
#
# Indexes
#
#  index_calendar_availability_rules_on_resource_date          (kanban_calendar_resource_id,date)
#  index_calendar_availability_rules_on_resource_kind_weekday  (kanban_calendar_resource_id,kind,weekday)
#
# Foreign Keys
#
#  fk_rails_...  (kanban_calendar_resource_id => kanban_calendar_resources.id)
#
class KanbanCalendarAvailabilityRule < ApplicationRecord
  KINDS = %w[weekly_window date_override block].freeze

  belongs_to :kanban_calendar_resource

  validates :kind, inclusion: { in: KINDS }
  validates :weekday, inclusion: { in: 0..6 }, if: :weekly_window?
  validates :date, presence: true, unless: :weekly_window?
  validates :starts_at_local, :ends_at_local, presence: true, unless: :block?
  validate :local_window_is_valid
  validate :block_window_is_complete

  scope :active, -> { where(active: true) }
  scope :for_date, ->(date) { where(date: [nil, date]) }

  def weekly_window?
    kind == 'weekly_window'
  end

  def date_override?
    kind == 'date_override'
  end

  def block?
    kind == 'block'
  end

  private

  def local_window_is_valid
    return if starts_at_local.blank? || ends_at_local.blank? || ends_at_local > starts_at_local

    errors.add(:ends_at_local, 'must be after the start time')
  end

  def block_window_is_complete
    return unless block?
    return if starts_at_local.blank? && ends_at_local.blank?
    return if starts_at_local.present? && ends_at_local.present?

    errors.add(:base, 'Block start and end times must be both present or both blank')
  end
end
