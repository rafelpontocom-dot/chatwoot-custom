FactoryBot.define do
  factory :kanban_card_event do
    account
    kanban_card { association(:kanban_card, account: account) }
    kanban_board { kanban_card.kanban_board }
    event_type { 'card_created' }
    occurred_at { Time.current }
    change_set { {} }
    metadata { {} }
  end
end
