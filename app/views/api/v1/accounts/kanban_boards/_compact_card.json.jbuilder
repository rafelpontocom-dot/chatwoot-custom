conversation = card.conversation
assignee = conversation&.assignee
owner = card.owner
closed_by = card.closed_by

json.id card.id
json.kanban_stage_id card.kanban_stage_id
json.position card.position
json.origin card.origin
json.subject card.subject
json.active card.active
json.due_at card.due_at&.iso8601
json.stage_entered_at card.stage_entered_at&.iso8601
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
json.expected_close_date card.expected_close_date&.iso8601
json.custom_field_values card.custom_field_values
json.compact_custom_fields card.compact_custom_fields
json.stale_in_stage card.stale_in_stage?
json.contact do
  json.partial! 'api/v1/models/contact', formats: [:json], resource: card.contact
end
json.inbox do
  json.partial! 'api/v1/models/inbox_slim', formats: [:json], resource: card.inbox
end
json.conversation_id conversation&.display_id
json.priority conversation&.priority
json.conversation do
  if conversation
    json.id conversation.id
    json.display_id conversation.display_id
  else
    json.nil!
  end
end
json.assignee do
  if assignee
    json.id assignee.id
    json.name assignee.name
    json.avatar_url assignee.avatar_url
  else
    json.nil!
  end
end
json.owner do
  if owner
    json.id owner.id
    json.name owner.name
    json.avatar_url owner.avatar_url
  else
    json.nil!
  end
end
json.closed_by do
  if closed_by
    json.id closed_by.id
    json.name closed_by.name
    json.avatar_url closed_by.avatar_url
  else
    json.nil!
  end
end
json.moved_by_id nil
json.moved_at nil
