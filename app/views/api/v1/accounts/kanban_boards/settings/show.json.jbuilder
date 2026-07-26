json.id @kanban_board.id
json.name @kanban_board.name
json.description @kanban_board.description
json.visibility_mode @kanban_board.visibility_mode
json.visible_user_ids @kanban_board.kanban_board_members.order(:user_id).pluck(:user_id)
json.inbox_scope_mode @kanban_board.inbox_scope_mode
json.allowed_inbox_ids @kanban_board.kanban_board_inboxes.order(:inbox_id).pluck(:inbox_id)
json.auto_create_cards_from_conversations @kanban_board.auto_create_cards_from_conversations
json.appointment_reminder_hours @kanban_board.appointment_reminder_hours
json.next_action_types @kanban_board.configured_next_action_types
json.lost_reason_options @kanban_board.configured_lost_reason_options
json.custom_field_definitions @kanban_board.configured_custom_field_definitions
json.custom_field_sections @kanban_board.configured_custom_field_sections
json.compact_card_field_keys @kanban_board.compact_card_field_keys
json.stale_stage_thresholds @kanban_board.stale_stage_thresholds
json.custom_field_usage @kanban_board.custom_field_usage
json.stages do
  json.array! @kanban_board.kanban_stages.active.ordered do |kanban_stage|
    json.partial! 'api/v1/accounts/kanban_boards/stage', formats: [:json], kanban_stage: kanban_stage
  end
end
json.lock_version @kanban_board.lock_version
