# == Schema Information
#
# Table name: kanban_calendar_resources
#
#  id            :bigint           not null, primary key
#  active        :boolean          default(TRUE), not null
#  capacity      :integer          default(1), not null
#  name          :string           not null
#  resource_type :string           not null
#  settings      :jsonb            not null
#  timezone      :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :bigint           not null
#  user_id       :bigint
#
# Indexes
#
#  index_kanban_calendar_resources_on_account_and_user  (account_id,user_id) UNIQUE WHERE (user_id IS NOT NULL)
#  index_kanban_calendar_resources_on_account_id        (account_id)
#  index_kanban_calendar_resources_on_user_id           (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (user_id => users.id)
#
class KanbanCalendarResource < ApplicationRecord
  RESOURCE_TYPES = %w[user room equipment generic].freeze

  belongs_to :account
  belongs_to :user, optional: true

  has_many :kanban_calendar_procedure_resources, dependent: :destroy
  has_many :kanban_calendar_procedures, through: :kanban_calendar_procedure_resources
  has_many :kanban_calendar_appointment_resources, dependent: :restrict_with_error
  has_many :kanban_calendar_appointments, through: :kanban_calendar_appointment_resources
  has_many :kanban_calendar_availability_rules, dependent: :destroy
  has_one :kanban_calendar_google_connection, dependent: :destroy

  validates :name, :timezone, presence: true
  validates :resource_type, inclusion: { in: RESOURCE_TYPES }
  validates :capacity, numericality: { only_integer: true, equal_to: 1 }
  validate :user_present_for_user_resource
  validate :user_belongs_to_account
  validate :valid_timezone

  scope :active, -> { where(active: true) }

  private

  def user_present_for_user_resource
    errors.add(:user, 'must be selected for a professional resource') if resource_type == 'user' && user.blank?
  end

  def user_belongs_to_account
    return if user.blank? || user.account_ids.include?(account_id)

    errors.add(:user, 'must belong to the account')
  end

  def valid_timezone
    return if timezone.blank? || TZInfo::Timezone.get(timezone)
  rescue TZInfo::InvalidTimezoneIdentifier
    errors.add(:timezone, 'must be a valid IANA timezone')
  end
end
