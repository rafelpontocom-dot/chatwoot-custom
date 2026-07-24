class AddRoundRobinCursorToKanbanAutomationRules < ActiveRecord::Migration[7.1]
  def change
    add_column :kanban_automation_rules, :round_robin_cursor, :integer, null: false, default: 0
  end
end
