# == Schema Information
#
# Table name: kanban_appointment_reminder_rules
#
#  id                       :bigint           not null, primary key
#  active                   :boolean          default(FALSE), not null
#  channels                 :jsonb            not null
#  field_key                :string           not null
#  lock_version             :integer          default(0), not null
#  message_templates        :jsonb            not null
#  offsets                  :jsonb            not null
#  opt_in_attribute_key     :string           default("appointment_reminders_opt_in"), not null
#  timezone_mode            :string           default("board"), not null
#  trigger_type             :string           default("stage_entered"), not null
#  whatsapp_template_params :jsonb            not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  account_id               :bigint           not null
#  kanban_board_id          :bigint           not null
#  trigger_stage_id         :bigint
#
# Indexes
#
#  idx_kanban_appointment_rules_on_trigger                     (kanban_board_id,trigger_type,trigger_stage_id)
#  index_kanban_appointment_reminder_rules_on_account_id       (account_id)
#  index_kanban_appointment_reminder_rules_on_kanban_board_id  (kanban_board_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (kanban_board_id => kanban_boards.id)
#  fk_rails_...  (trigger_stage_id => kanban_stages.id)
#
class KanbanAppointmentReminderRule < ApplicationRecord
  TRIGGER_TYPES = %w[stage_entered card_created appointment_changed manual].freeze
  TIMEZONE_MODES = %w[contact board account].freeze
  CHANNELS = %w[whatsapp email].freeze

  belongs_to :account
  belongs_to :kanban_board
  belongs_to :trigger_stage, class_name: 'KanbanStage', optional: true
  has_many :deliveries, class_name: 'KanbanAppointmentReminderDelivery', dependent: :destroy

  scope :active, -> { where(active: true) }

  validates :field_key, presence: true
  validates :trigger_type, inclusion: { in: TRIGGER_TYPES }
  validates :timezone_mode, inclusion: { in: TIMEZONE_MODES }
  validates :channels, presence: true
  validate :trigger_stage_belongs_to_board
  validate :offsets_are_supported
  validate :channels_are_supported
  validate :account_context

  private

  def account_context
    return if account.blank? || kanban_board.blank?

    errors.add(:kanban_board, :invalid) unless account_id == kanban_board.account_id
  end

  def trigger_stage_belongs_to_board
    return unless trigger_type == 'stage_entered'
    return if trigger_stage.present? && trigger_stage.kanban_board_id == kanban_board_id

    errors.add(:trigger_stage_id, :blank)
  end

  def offsets_are_supported
    values = Array(offsets)
    errors.add(:offsets, 'must contain at least one offset') if values.empty?
    valid_offsets = values.all? { |value| value.to_i.positive? } && values.uniq.length == values.length
    errors.add(:offsets, 'must contain unique positive hours') unless valid_offsets
    errors.add(:offsets, 'cannot exceed 365 days') if values.any? { |value| value.to_i > 24 * 365 }
  end

  def channels_are_supported
    invalid = Array(channels).map(&:to_s) - CHANNELS
    errors.add(:channels, "unsupported channels: #{invalid.join(', ')}") if invalid.present?
  end
end
