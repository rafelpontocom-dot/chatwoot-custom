# == Schema Information
#
# Table name: kanban_appointment_reminder_deliveries
#
#  id                                  :bigint           not null, primary key
#  appointment_value                   :string           not null
#  appointment_version                 :string           not null
#  attempted_at                        :datetime
#  delivery_channel                    :string           not null
#  error_message                       :text
#  idempotency_key                     :string           not null
#  offset_hours                        :integer          not null
#  scheduled_at                        :datetime         not null
#  sent_at                             :datetime
#  status                              :string           default("scheduled"), not null
#  created_at                          :datetime         not null
#  updated_at                          :datetime         not null
#  account_id                          :bigint           not null
#  kanban_appointment_reminder_rule_id :bigint           not null
#  kanban_board_id                     :bigint           not null
#  kanban_card_id                      :bigint           not null
#  message_id                          :bigint
#
# Indexes
#
#  idx_kanban_reminder_deliveries_on_due                           (status,scheduled_at)
#  idx_kanban_reminder_deliveries_on_idempotency                   (idempotency_key) UNIQUE
#  idx_kanban_reminder_deliveries_on_rule                          (kanban_appointment_reminder_rule_id)
#  idx_on_kanban_board_id_c50d2652b4                               (kanban_board_id)
#  index_kanban_appointment_reminder_deliveries_on_account_id      (account_id)
#  index_kanban_appointment_reminder_deliveries_on_kanban_card_id  (kanban_card_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (kanban_appointment_reminder_rule_id => kanban_appointment_reminder_rules.id)
#  fk_rails_...  (kanban_board_id => kanban_boards.id)
#  fk_rails_...  (kanban_card_id => kanban_cards.id)
#  fk_rails_...  (message_id => messages.id)
#
class KanbanAppointmentReminderDelivery < ApplicationRecord
  STATUSES = %w[scheduled sending sent skipped failed canceled].freeze

  belongs_to :account
  belongs_to :kanban_board
  belongs_to :kanban_card
  belongs_to :kanban_appointment_reminder_rule
  belongs_to :message, optional: true

  enum :status, STATUSES.index_by(&:itself), validate: true
  validates :idempotency_key, :appointment_version, :appointment_value, presence: true
  validates :idempotency_key, uniqueness: true

  scope :due, -> { scheduled.where(scheduled_at: ..Time.current) }
end
