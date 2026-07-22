FactoryBot.define do
  factory :kanban_automation_execution do
    account
    kanban_automation_rule { association(:kanban_automation_rule, account: account) }
    event_name { kanban_automation_rule.event_name }
    sequence(:event_key) { |n| "event-#{n}" }
    status { 'queued' }
    action_results { [] }
  end
end
