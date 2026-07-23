class AddVisualFlowToKanbanAutomations < ActiveRecord::Migration[7.1]
  def change
    add_column :kanban_automation_rules, :flow_definition, :jsonb, null: false, default: {}
    add_column :kanban_automation_executions, :workflow_state, :jsonb, null: false, default: {}
    add_column :kanban_automation_executions, :scheduled_at, :datetime
    add_index :kanban_automation_executions, [:status, :scheduled_at], name: 'idx_kanban_automation_executions_on_schedule'
  end
end
