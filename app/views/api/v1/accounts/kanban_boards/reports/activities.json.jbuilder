json.cards do
  json.array! @cards do |card|
    json.partial!(
      'api/v1/accounts/kanban_boards/compact_card',
      formats: [:json],
      card: card
    )
    json.stage_name card.kanban_stage.name
  end
end

json.pagination do
  json.page @page
  json.limit @limit
  json.has_more @has_more
end
