class CreateKanbanSavedFilters < ActiveRecord::Migration[7.1]
  def change
    create_table :kanban_saved_filters do |t|
      t.references :account, null: false, foreign_key: true
      t.references :kanban_board, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.jsonb :filters, null: false, default: {}
      t.timestamps
    end

    add_index :kanban_saved_filters,
              [:kanban_board_id, :user_id, :name],
              unique: true,
              name: 'index_kanban_saved_filters_unique_name'
  end
end
