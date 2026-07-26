class CreateKanbanAutomationConnectionAudits < ActiveRecord::Migration[7.1]
  def change
    create_table :kanban_automation_connection_audits do |t|
      t.references :account, null: false, foreign_key: true
      t.references :kanban_board, null: false, foreign_key: true
      t.references :kanban_automation_connection, foreign_key: true
      t.references :actor, foreign_key: { to_table: :users }
      t.string :action, null: false
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :kanban_automation_connection_audits,
              %i[kanban_board_id created_at],
              name: 'idx_kanban_connection_audits_board_created'
  end
end
