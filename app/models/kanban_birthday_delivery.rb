# == Schema Information
#
# Table name: kanban_birthday_deliveries
#
#  id                            :bigint           not null, primary key
#  attempted_at                  :datetime
#  birthday_year                 :integer          not null
#  delivery_channel              :string           not null
#  error_message                 :text
#  sent_at                       :datetime
#  skipped_at                    :datetime
#  status                        :string           default("pending"), not null
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  account_id                    :bigint           not null
#  contact_id                    :bigint           not null
#  kanban_birthday_automation_id :bigint           not null
#  message_id                    :bigint
#
# Indexes
#
#  idx_birthday_deliveries_on_automation           (kanban_birthday_automation_id)
#  idx_kanban_birthday_deliveries_processing       (account_id,status,created_at)
#  idx_unique_kanban_birthday_deliveries           (account_id,contact_id,birthday_year,delivery_channel) UNIQUE
#  index_kanban_birthday_deliveries_on_account_id  (account_id)
#  index_kanban_birthday_deliveries_on_contact_id  (contact_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (kanban_birthday_automation_id => kanban_birthday_automations.id)
#
class KanbanBirthdayDelivery < ApplicationRecord
  STATUSES = %w[pending sending sent skipped failed].freeze

  belongs_to :account
  belongs_to :contact
  belongs_to :kanban_birthday_automation

  enum :status, STATUSES.index_by(&:itself)

  validates :birthday_year, numericality: { only_integer: true }
  validates :delivery_channel, inclusion: { in: KanbanBirthdayAutomation::CHANNELS }
  validates :status, presence: true
  validates :delivery_channel, uniqueness: {
    scope: [:account_id, :contact_id, :birthday_year]
  }
end
