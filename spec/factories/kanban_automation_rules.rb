FactoryBot.define do
  factory :kanban_automation_rule do
    account
    kanban_board { association(:kanban_board, account: account) }
    sequence(:name) { |n| "Automation rule #{n}" }
    event_name { Events::Types::KANBAN_CARD_STAGE_CHANGED }
    conditions { {} }
    actions { [] }
    active { true }
    position { 0 }
  end
end
