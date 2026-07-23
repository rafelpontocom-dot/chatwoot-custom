class AddKanbanAutomationConnections < ActiveRecord::Migration[7.1]
  def change
    create_table :kanban_automation_connections do |t|
      t.references :account, null: false, foreign_key: true
      t.references :kanban_board, null: false, foreign_key: true
      t.string :name, null: false
      t.string :webhook_url, null: false
      t.text :secret, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :kanban_automation_connections,
              [:kanban_board_id, :name],
              unique: true,
              name: 'idx_kanban_automation_connections_board_name'

    add_reference :kanban_automation_executions, :kanban_card, foreign_key: true
  end
end
