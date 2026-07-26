class AddOverdueNextActionIndexToKanbanCards < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :kanban_cards,
              :next_action_at,
              where: 'active = true AND next_action_completed_at IS NULL AND won_at IS NULL AND lost_at IS NULL',
              name: 'index_open_kanban_cards_on_next_action_at',
              algorithm: :concurrently
  end
end
