FactoryBot.define do
  factory :kanban_automation_connection do
    account
    kanban_board { create(:kanban_board, account: account) }
    sequence(:name) { |n| "Webhook #{n}" }
    webhook_url { 'https://automacao.example.test/hooks/lead' }
    active { true }
  end
end
