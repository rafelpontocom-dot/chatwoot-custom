FactoryBot.define do
  factory :kanban_cadence do
    account
    kanban_board { association(:kanban_board, account: account) }
    sequence(:name) { |n| "Follow-up cadence #{n}" }
    steps { [{ delay_hours: 0, action_type: 'Follow-up', note: 'Realizar follow-up' }] }
    active { true }
    pause_on_incoming_message { true }
  end
end
