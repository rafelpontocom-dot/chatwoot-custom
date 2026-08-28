# == Schema Information
#
# Table name: kanban_calendar_procedures
#
#  id                     :bigint           not null, primary key
#  active                 :boolean          default(TRUE), not null
#  allowed_intervals      :jsonb            not null
#  board_ids              :jsonb            not null
#  buffer_after_minutes   :integer          default(0), not null
#  buffer_before_minutes  :integer          default(0), not null
#  color                  :string
#  duration_minutes       :integer          not null
#  location_type          :string           default("in_person"), not null
#  max_sessions           :integer
#  name                   :string           not null
#  public_booking_config  :jsonb            not null
#  public_booking_enabled :boolean          default(FALSE), not null
#  public_description     :text
#  public_slug            :string
#  public_title           :string
#  recurrence_allowed     :boolean          default(FALSE), not null
#  stage_policy           :jsonb            not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  account_id             :bigint           not null
#
# Indexes
#
#  index_calendar_procedures_on_account_and_public_slug        (account_id, lower((public_slug)::text)) UNIQUE WHERE (public_slug IS NOT NULL)
#  index_kanban_calendar_procedures_on_account_and_lower_name  (account_id, lower((name)::text)) UNIQUE
#  index_kanban_calendar_procedures_on_account_id              (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class KanbanCalendarProcedure < ApplicationRecord
  LOCATION_TYPES = %w[in_person video phone other].freeze
  INTERVAL_KINDS = %w[weekly biweekly monthly].freeze

  belongs_to :account

  has_many :kanban_calendar_procedure_resources, dependent: :destroy
  has_many :kanban_calendar_resources, through: :kanban_calendar_procedure_resources
  has_many :kanban_calendar_appointment_series, dependent: :restrict_with_error
  has_many :kanban_calendar_appointments, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :account_id, case_sensitive: false }
  validates :duration_minutes, numericality: { only_integer: true, in: 5..480 }
  validates :buffer_before_minutes, :buffer_after_minutes, numericality: { only_integer: true, in: 0..120 }
  validates :location_type, inclusion: { in: LOCATION_TYPES }
  validates :max_sessions, numericality: { only_integer: true, in: 1..100 }, if: :recurrence_allowed?
  validates :public_slug,
            format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ },
            allow_blank: true
  validates :public_slug, presence: true, if: :public_booking_enabled?
  validate :max_sessions_absent_without_recurrence
  validate :allowed_intervals_are_supported

  scope :active, -> { where(active: true) }

  private

  def max_sessions_absent_without_recurrence
    return if recurrence_allowed? || max_sessions.blank?

    errors.add(:max_sessions, 'must be blank when recurrence is disabled')
  end

  def allowed_intervals_are_supported
    return if allowed_intervals.all? { |interval| interval.in?(INTERVAL_KINDS) || interval.to_s.match?(/\Adays:\d+\z/) }

    errors.add(:allowed_intervals, 'contains an unsupported interval')
  end
end
