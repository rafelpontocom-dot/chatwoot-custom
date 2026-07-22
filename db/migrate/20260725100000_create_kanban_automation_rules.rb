class CreateKanbanAutomationRules < ActiveRecord::Migration[7.1]
  def change
    create_table :kanban_automation_rules do |t|
      t.references :account, null: false, foreign_key: true
      t.references :kanban_board, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.string :event_name, null: false
      t.jsonb :conditions, null: false, default: {}
      t.jsonb :actions, null: false, default: []
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_index :kanban_automation_rules,
              [:account_id, :kanban_board_id, :event_name, :active],
              name: 'idx_kanban_automation_rules_lookup'
    add_index :kanban_automation_rules,
              [:kanban_board_id, :name],
              unique: true,
              name: 'idx_kanban_automation_rules_board_name'

    create_table :kanban_automation_executions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :kanban_automation_rule, null: false, foreign_key: true
      t.references :kanban_card_event, foreign_key: true
      t.string :event_name, null: false
      t.string :event_key, null: false
      t.string :status, null: false, default: 'queued'
      t.jsonb :action_results, null: false, default: []
      t.text :error_message
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end

    add_index :kanban_automation_executions,
              [:kanban_automation_rule_id, :event_key],
              unique: true,
              name: 'idx_kanban_automation_executions_idempotency'
    add_index :kanban_automation_executions,
              [:account_id, :status, :created_at],
              name: 'idx_kanban_automation_executions_history'
  end
end
