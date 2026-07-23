class AddReentryEnabledToKanbanAutomationRules < ActiveRecord::Migration[7.1]
  def change
    add_column :kanban_automation_rules, :reentry_enabled, :boolean, null: false, default: false
  end
end
