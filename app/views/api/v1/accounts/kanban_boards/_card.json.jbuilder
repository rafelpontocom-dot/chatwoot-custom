conversation_kanban_state ||= nil
card ||= conversation_kanban_state
stable_card ||= false

json.id card.id
json.account_id card.account_id
json.kanban_board_id card.kanban_board_id
json.kanban_stage_id card.kanban_stage_id
json.conversation_id card.conversation&.display_id
json.position card.position
json.moved_by_id nil
json.moved_at nil
json.created_at card.created_at.to_i
json.updated_at card.updated_at.to_i
json.stage_entered_at card.stage_entered_at&.iso8601 if card.respond_to?(:stage_entered_at)
json.origin card.origin if card.respond_to?(:origin)
json.subject card.subject if card.respond_to?(:subject)
if stable_card
  json.description card.description
  json.starts_at card.starts_at&.iso8601
  json.due_at card.due_at&.iso8601
  json.owner_id card.owner_id
  json.next_action_type card.next_action_type
  json.next_action_at card.next_action_at&.iso8601
  json.next_action_note card.next_action_note
  json.next_action_completed_at card.next_action_completed_at&.iso8601
  json.next_action_status card.next_action_status
  json.won_at card.won_at&.iso8601
  json.lost_at card.lost_at&.iso8601
  json.lost_reason card.lost_reason
  json.closed_by_id card.closed_by_id
  json.amount_cents card.amount_cents
  json.amount_currency card.amount_currency
  json.custom_field_values card.custom_field_values
  json.next_action_history card.next_action_history
  json.compact_custom_fields card.compact_custom_fields
  json.stale_in_stage card.stale_in_stage?
  json.owner do
    if card.owner
      json.id card.owner.id
      json.name card.owner.name
      json.avatar_url card.owner.avatar_url
    else
      json.nil!
    end
  end
  json.closed_by do
    if card.closed_by
      json.id card.closed_by.id
      json.name card.closed_by.name
      json.avatar_url card.closed_by.avatar_url
    else
      json.nil!
    end
  end
end
json.active card.active if card.respond_to?(:active)
if card.respond_to?(:origin)
  json.contact do
    json.partial! 'api/v1/models/contact', formats: [:json], resource: card.contact
  end
  json.inbox do
    json.partial! 'api/v1/models/inbox_slim', formats: [:json], resource: card.inbox
  end
end
if card.conversation.present?
  json.conversation do
    json.partial!(
      'api/v1/conversations/partials/conversation',
      formats: [:json],
      conversation: card.conversation
    )
  end
else
  json.conversation nil
end
