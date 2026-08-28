class AddPresentationFieldsToKanbanStages < ActiveRecord::Migration[7.1]
  def change
    add_column :kanban_stages, :description, :text
    add_column :kanban_stages, :icon, :string, null: false, default: 'circle-dot'
  end
end
