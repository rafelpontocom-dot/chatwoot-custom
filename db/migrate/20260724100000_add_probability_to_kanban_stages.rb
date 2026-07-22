class AddProbabilityToKanbanStages < ActiveRecord::Migration[7.1]
  def up
    add_column :kanban_stages, :probability, :integer, null: false, default: 0

    execute "UPDATE kanban_stages SET probability = 100 WHERE category = 'won'"
    execute "UPDATE kanban_stages SET probability = 0 WHERE category = 'lost'"

    add_check_constraint :kanban_stages, 'probability >= 0 AND probability <= 100',
                         name: 'kanban_stages_probability_check'
  end

  def down
    remove_check_constraint :kanban_stages, name: 'kanban_stages_probability_check'
    remove_column :kanban_stages, :probability
  end
end
