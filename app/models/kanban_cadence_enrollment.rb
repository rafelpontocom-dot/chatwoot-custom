# == Schema Information
#
# Table name: kanban_cadence_enrollments
#
#  id                :bigint           not null, primary key
#  completed_at      :datetime
#  current_step      :integer          default(0), not null
#  last_error        :text
#  last_run_at       :datetime
#  lock_version      :integer          default(0), not null
#  next_run_at       :datetime
#  paused_at         :datetime
#  started_at        :datetime         not null
#  status            :string           default("active"), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint           not null
#  kanban_board_id   :bigint           not null
#  kanban_cadence_id :bigint           not null
#  kanban_card_id    :bigint           not null
#  owner_id          :bigint
#
# Indexes
#
#  idx_kanban_cadence_enrollments_account_status          (account_id,status)
#  idx_kanban_cadence_enrollments_card_cadence            (kanban_card_id,kanban_cadence_id) UNIQUE
#  idx_kanban_cadence_enrollments_due                     (status,next_run_at)
#  index_kanban_cadence_enrollments_on_account_id         (account_id)
#  index_kanban_cadence_enrollments_on_kanban_board_id    (kanban_board_id)
#  index_kanban_cadence_enrollments_on_kanban_cadence_id  (kanban_cadence_id)
#  index_kanban_cadence_enrollments_on_kanban_card_id     (kanban_card_id)
#  index_kanban_cadence_enrollments_on_owner_id           (owner_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (kanban_board_id => kanban_boards.id)
#  fk_rails_...  (kanban_cadence_id => kanban_cadences.id)
#  fk_rails_...  (kanban_card_id => kanban_cards.id)
#  fk_rails_...  (owner_id => users.id)
#
class KanbanCadenceEnrollment < ApplicationRecord
  STATUSES = %w[active awaiting_completion paused completed canceled].freeze

  belongs_to :account
  belongs_to :kanban_board
  belongs_to :kanban_card
  belongs_to :kanban_cadence
  belongs_to :owner, class_name: 'User', optional: true

  enum :status, STATUSES.index_by(&:itself), validate: true

  validates :account, :kanban_board, :kanban_card, :kanban_cadence, presence: true
  validates :started_at, presence: true
  validates :current_step, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :kanban_card_id, uniqueness: { scope: :kanban_cadence_id }
  validate :records_share_context

  scope :due, -> { active.where(next_run_at: ..Time.current) }

  private

  def records_share_context
    return if account.blank? || kanban_board.blank? || kanban_card.blank? || kanban_cadence.blank?

    validate_board_context
    validate_card_context
    validate_cadence_context
  end

  def validate_board_context
    return if account_id == kanban_board.account_id

    errors.add(:kanban_board, :invalid)
  end

  def validate_card_context
    return if account_id == kanban_card.account_id && kanban_board_id == kanban_card.kanban_board_id

    errors.add(:kanban_card, :invalid)
  end

  def validate_cadence_context
    return if account_id == kanban_cadence.account_id && kanban_board_id == kanban_cadence.kanban_board_id

    errors.add(:kanban_cadence, :invalid)
  end
end
