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
    card_created fields_changed stage_changed owner_changed amount_changed custom_fields_changed
    next_action_scheduled next_action_completed card_won card_lost card_reopened
    card_archived card_restored automation_logged
  ].freeze
  DOMAIN_EVENT_TYPES = {
    'fields_changed' => Events::Types::KANBAN_CARD_FIELDS_CHANGED,
    'stage_changed' => Events::Types::KANBAN_CARD_STAGE_CHANGED,
    'owner_changed' => Events::Types::KANBAN_CARD_OWNER_CHANGED,
    'amount_changed' => Events::Types::KANBAN_CARD_AMOUNT_CHANGED,
    'custom_fields_changed' => Events::Types::KANBAN_CARD_CUSTOM_FIELDS_CHANGED,
    'next_action_scheduled' => Events::Types::KANBAN_CARD_NEXT_ACTION_SCHEDULED,
    'next_action_completed' => Events::Types::KANBAN_CARD_NEXT_ACTION_COMPLETED,
    'card_won' => Events::Types::KANBAN_CARD_WON,
    'card_lost' => Events::Types::KANBAN_CARD_LOST,
    'card_reopened' => Events::Types::KANBAN_CARD_REOPENED,
    'card_archived' => Events::Types::KANBAN_CARD_ARCHIVED,
    'card_restored' => Events::Types::KANBAN_CARD_RESTORED
  }.freeze

  belongs_to :account
  belongs_to :kanban_board
  belongs_to :kanban_card
  belongs_to :actor, polymorphic: true, optional: true

  has_many :kanban_automation_executions, dependent: :nullify

  validates :event_type, inclusion: { in: EVENT_TYPES }
  validates :occurred_at, presence: true
  validate :validate_card_context

  before_update :prevent_mutation
  before_destroy :prevent_mutation
  after_create_commit :dispatch_domain_event, if: :domain_event_type?

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

  def domain_event_type?
    DOMAIN_EVENT_TYPES.key?(event_type)
  end

  def dispatch_domain_event
    dispatch_event(DOMAIN_EVENT_TYPES.fetch(event_type))
    dispatch_event(Events::Types::KANBAN_CARD_FIELDS_CHANGED) if fields_changed?
  end

  def fields_changed?
    event_type != 'fields_changed' && event_type != 'automation_logged' && change_set.present?
  end

  def dispatch_event(event_name)
    Rails.configuration.dispatcher.dispatch(
      event_name,
      occurred_at,
      {
        account_id: account_id,
        board_id: kanban_board_id,
        stage_id: kanban_card.kanban_stage_id,
        card_id: kanban_card_id,
        contact_id: kanban_card.contact_id,
        conversation_id: kanban_card.conversation_id,
        owner_id: kanban_card.owner_id,
        event_id: id,
        event_type: event_type,
        occurred_at: occurred_at,
        change_set: change_set,
        metadata: metadata
      }
    )
  end
end
