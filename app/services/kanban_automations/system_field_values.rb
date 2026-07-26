class KanbanAutomations::SystemFieldValues
  VALUES = {
    'system_subject' => ->(card) { card.subject },
    'system_description' => ->(card) { card.description },
    'system_amount' => ->(card) { card.amount_cents && (card.amount_cents.to_f / 100) },
    'system_owner_id' => ->(card) { card.owner_id },
    'system_stage_id' => ->(card) { card.kanban_stage_id },
    'system_inbox_id' => ->(card) { card.inbox_id },
    'system_status' => lambda do |card|
      if card.open_opportunity?
        'open'
      elsif card.won_at.present?
        'won'
      else
        'lost'
      end
    end,
    'system_starts_at' => ->(card) { card.starts_at },
    'system_due_at' => ->(card) { card.due_at },
    'system_next_action_type' => ->(card) { card.next_action_type },
    'system_next_action_at' => ->(card) { card.next_action_at },
    'system_next_action_note' => ->(card) { card.next_action_note },
    'system_next_action_completed' => ->(card) { card.next_action_completed_at.present? },
    'system_lost_reason' => ->(card) { card.lost_reason },
    'system_contact_id' => ->(card) { card.contact_id },
    'system_conversation_id' => ->(card) { card.conversation_id }
  }.freeze

  def initialize(card:)
    @card = card
  end

  def value(field_key)
    VALUES[field_key]&.call(card)
  end

  private

  attr_reader :card
end
