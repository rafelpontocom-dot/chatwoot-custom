class AddCustomFieldSectionsToKanbanBoards < ActiveRecord::Migration[7.1]
  def change
    add_column :kanban_boards, :custom_field_sections, :jsonb, default: [], null: false
  end
end
