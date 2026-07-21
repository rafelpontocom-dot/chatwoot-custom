class AddCustomSalesFieldsToKanban < ActiveRecord::Migration[7.1]
  def change
    add_column :kanban_boards, :custom_field_definitions, :jsonb, default: [], null: false

    add_column :kanban_cards, :amount_cents, :bigint
    add_column :kanban_cards, :amount_currency, :string, default: 'BRL', null: false
    add_column :kanban_cards, :custom_field_values, :jsonb, default: {}, null: false

    add_index :kanban_cards, [:kanban_board_id, :amount_cents]
  end
end
