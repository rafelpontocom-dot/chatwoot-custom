class AddSalesConfigurationToKanbanBoards < ActiveRecord::Migration[7.1]
  def change
    add_column :kanban_boards, :next_action_types, :jsonb, default: [], null: false
    add_column :kanban_boards, :lost_reason_options, :jsonb, default: [], null: false
  end
end
