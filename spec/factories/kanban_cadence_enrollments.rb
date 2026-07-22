FactoryBot.define do
  factory :kanban_cadence_enrollment do
    account
    kanban_board { association(:kanban_board, account: account) }
    kanban_card { association(:kanban_card, account: account, kanban_board: kanban_board) }
    kanban_cadence { association(:kanban_cadence, account: account, kanban_board: kanban_board) }
    current_step { 0 }
    status { 'active' }
    next_run_at { 1.hour.from_now }
    started_at { Time.current }
  end
end
