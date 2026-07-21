class AddAdvancedSalesConfigurationToKanban < ActiveRecord::Migration[7.1]
  def change
    add_column :kanban_boards, :compact_card_field_keys, :jsonb, default: [], null: false
    add_column :kanban_boards, :stale_stage_thresholds, :jsonb, default: {}, null: false

    add_column :kanban_cards, :next_action_history, :jsonb, default: [], null: false
  end
end
