class CompleteKanbanOperations < ActiveRecord::Migration[7.1]
  def change
    add_column :kanban_boards, :archived_at, :datetime unless column_exists?(:kanban_boards, :archived_at)
    add_reference :kanban_boards, :archived_by, foreign_key: { to_table: :users } unless column_exists?(:kanban_boards, :archived_by_id)
    add_column :kanban_boards, :lock_version, :integer, null: false, default: 0 unless column_exists?(:kanban_boards, :lock_version)
    add_index :kanban_boards, [:account_id, :archived_at] unless index_exists?(:kanban_boards, [:account_id, :archived_at])

    add_column :kanban_cards, :lock_version, :integer, null: false, default: 0 unless column_exists?(:kanban_cards, :lock_version)
  end
end
