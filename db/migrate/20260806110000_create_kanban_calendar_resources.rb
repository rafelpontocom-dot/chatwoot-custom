class CreateKanbanCalendarResources < ActiveRecord::Migration[7.1]
  def change
    create_table :kanban_calendar_resources do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :name, null: false
      t.string :resource_type, null: false
      t.string :timezone, null: false
      t.integer :capacity, null: false, default: 1
      t.boolean :active, null: false, default: true
      t.jsonb :settings, null: false, default: {}

      t.timestamps
    end

    add_index :kanban_calendar_resources,
              [:account_id, :user_id],
              unique: true,
              where: 'user_id IS NOT NULL',
              name: 'index_kanban_calendar_resources_on_account_and_user'
  end
end
