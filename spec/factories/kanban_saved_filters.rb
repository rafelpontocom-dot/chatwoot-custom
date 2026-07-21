FactoryBot.define do
  factory :kanban_saved_filter do
    account
    kanban_board { association(:kanban_board, account: account) }
    user { association(:user, account: account) }
    sequence(:name) { |index| "Saved filter #{index}" }
    filters { {} }
  end
end
