# == Schema Information
#
# Table name: kanban_card_events
#
#  id              :bigint           not null, primary key
#  actor_type      :string
#  change_set      :jsonb            not null
#  event_type      :string           not null
#  metadata        :jsonb            not null
#  occurred_at     :datetime         not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  actor_id        :bigint
#  kanban_board_id :bigint           not null
#  kanban_card_id  :bigint           not null
#
# Indexes
#
#  idx_on_account_id_event_type_occurred_at_0adaf08708  (account_id,event_type,occurred_at)
#  index_kanban_card_events_on_account_id               (account_id)
#  index_kanban_card_events_on_actor_type_and_actor_id  (actor_type,actor_id)
#  index_kanban_card_events_on_kanban_board_id          (kanban_board_id)
#  index_kanban_card_events_on_kanban_card_id           (kanban_card_id)
#  index_kanban_card_events_timeline                    (kanban_card_id,occurred_at,id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (kanban_board_id => kanban_boards.id)
#  fk_rails_...  (kanban_card_id => kanban_cards.id)
#
class KanbanCardEvent < ApplicationRecord
  EVENT_TYPES = %w[
    card_created stage_changed owner_changed amount_changed custom_fields_changed
    next_action_scheduled next_action_completed card_won card_lost card_reopened
    card_archived card_restored
  ].freeze

  belongs_to :account
  belongs_to :kanban_board
  belongs_to :kanban_card
  belongs_to :actor, polymorphic: true, optional: true

  validates :event_type, inclusion: { in: EVENT_TYPES }
  validates :occurred_at, presence: true
  validate :validate_card_context

  before_update :prevent_mutation
  before_destroy :prevent_mutation

  private

  def prevent_mutation
    errors.add(:base, 'Kanban card events are immutable')
    throw :abort
  end

  def validate_card_context
    return if kanban_card.blank?

    errors.add(:account_id, :invalid) if account_id != kanban_card.account_id
    errors.add(:kanban_board_id, :invalid) if kanban_board_id != kanban_card.kanban_board_id
  end
end
