# == Schema Information
#
# Table name: kanban_cadences
#
#  id                        :bigint           not null, primary key
#  active                    :boolean          default(TRUE), not null
#  lock_version              :integer          default(0), not null
#  name                      :string           not null
#  pause_on_incoming_message :boolean          default(TRUE), not null
#  steps                     :jsonb            not null
#  trigger_type              :string           default("manual"), not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  account_id                :bigint           not null
#  kanban_board_id           :bigint           not null
#  trigger_stage_id          :bigint
#
# Indexes
#
#  idx_kanban_cadences_on_stage_trigger               (kanban_board_id,trigger_type,trigger_stage_id)
#  index_kanban_cadences_on_account_id                (account_id)
#  index_kanban_cadences_on_account_id_and_active     (account_id,active)
#  index_kanban_cadences_on_kanban_board_id           (kanban_board_id)
#  index_kanban_cadences_on_kanban_board_id_and_name  (kanban_board_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (kanban_board_id => kanban_boards.id)
#  fk_rails_...  (trigger_stage_id => kanban_stages.id)
#
class KanbanCadence < ApplicationRecord
  MAX_STEPS = 20
  MAX_DELAY_HOURS = 24 * 365
  DISALLOWED_ACTION_TYPES = %w[send_message send_template send_whatsapp].freeze
  TRIGGER_TYPES = %w[manual stage_entered].freeze

  belongs_to :account
  belongs_to :kanban_board
  belongs_to :trigger_stage, class_name: 'KanbanStage', optional: true
  has_many :kanban_cadence_enrollments, dependent: :destroy

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name, :id) }

  validates :name, presence: true, uniqueness: { scope: :kanban_board_id }
  validates :account, :kanban_board, presence: true
  validate :board_belongs_to_account
  validate :steps_are_supported
  validates :trigger_type, inclusion: { in: TRIGGER_TYPES }
  validate :stage_trigger_belongs_to_board

  private

  def board_belongs_to_account
    return if account.blank? || kanban_board.blank?
    return if account_id == kanban_board.account_id

    errors.add(:kanban_board, :invalid)
  end

  def stage_trigger_belongs_to_board
    return unless trigger_type == 'stage_entered'
    return if trigger_stage_id.present? && kanban_board&.kanban_stages&.exists?(id: trigger_stage_id)

    errors.add(:trigger_stage_id, :invalid)
  end

  def steps_are_supported
    source = Array(steps)
    validate_step_count(source)

    source.each_with_index do |step, index|
      validate_step(step, index)
    end
  end

  def validate_step_count(source)
    errors.add(:steps, 'must contain at least one step') if source.empty?
    return unless source.length > MAX_STEPS

    errors.add(:steps, "cannot contain more than #{MAX_STEPS} steps")
  end

  def validate_step(step, index)
    attributes = step.to_h.with_indifferent_access
    errors.add(:steps, "Step #{index + 1} has an invalid delay") unless valid_delay?(attributes[:delay_hours])

    if attributes[:action_type].blank?
      errors.add(:steps, "Step #{index + 1} needs an action type")
    elsif DISALLOWED_ACTION_TYPES.include?(attributes[:action_type].to_s)
      errors.add(:steps, "Step #{index + 1} cannot send a customer message")
    end
  end

  def valid_delay?(value)
    value.to_s.match?(/\A\d+(?:\.\d+)?\z/) && value.to_f <= MAX_DELAY_HOURS
  end
end
