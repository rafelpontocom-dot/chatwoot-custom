class AddStructuralSalesFieldsToKanban < ActiveRecord::Migration[7.1]
  # rubocop:disable Metrics/MethodLength
  def change
    add_column :kanban_stages, :category, :string, null: false, default: 'open'
    add_column :kanban_stages, :wip_limit, :integer
    add_check_constraint :kanban_stages, "category IN ('open', 'won', 'lost')", name: 'kanban_stages_category_check'
    add_check_constraint :kanban_stages, 'wip_limit IS NULL OR wip_limit > 0', name: 'kanban_stages_wip_limit_check'
    add_index :kanban_stages, [:kanban_board_id, :category]

    add_column :kanban_cards, :expected_close_date, :date
    add_column :kanban_cards, :archived_at, :datetime
    add_reference :kanban_cards, :archived_by, foreign_key: { to_table: :users }
    add_index :kanban_cards, [:kanban_board_id, :expected_close_date]
    add_index :kanban_cards, [:kanban_board_id, :archived_at]

    create_table :kanban_card_events do |t|
      t.references :account, null: false, foreign_key: true
      t.references :kanban_board, null: false, foreign_key: true
      t.references :kanban_card, null: false, foreign_key: true
      t.string :event_type, null: false
      t.string :actor_type
      t.bigint :actor_id
      t.datetime :occurred_at, null: false
      t.jsonb :change_set, null: false, default: {}
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :kanban_card_events, [:kanban_card_id, :occurred_at, :id], name: 'index_kanban_card_events_timeline'
    add_index :kanban_card_events, [:actor_type, :actor_id]
    add_index :kanban_card_events, [:account_id, :event_type, :occurred_at]
  end
  # rubocop:enable Metrics/MethodLength
end
