class AddSalesFieldsToKanbanCards < ActiveRecord::Migration[7.1]
  def change
    add_column :kanban_cards, :owner_id, :bigint
    add_column :kanban_cards, :next_action_type, :string
    add_column :kanban_cards, :next_action_at, :datetime
    add_column :kanban_cards, :next_action_note, :text
    add_column :kanban_cards, :next_action_completed_at, :datetime
    add_column :kanban_cards, :won_at, :datetime
    add_column :kanban_cards, :lost_at, :datetime
    add_column :kanban_cards, :lost_reason, :string
    add_column :kanban_cards, :closed_by_id, :bigint

    add_index :kanban_cards, [:account_id, :next_action_at]
    add_index :kanban_cards, [:kanban_board_id, :next_action_at]
    add_index :kanban_cards, [:owner_id, :next_action_at]
    add_index :kanban_cards, [:kanban_board_id, :lost_at]
    add_index :kanban_cards, [:kanban_board_id, :won_at]
  end
end
