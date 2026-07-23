class AddSnapshotsToKanbanAutomationExecutions < ActiveRecord::Migration[7.1]
  def change
    add_column :kanban_automation_executions, :automation_snapshot, :jsonb, null: false, default: {}
  end
end
