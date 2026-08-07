class CreateKanbanCalendarAvailabilityRules < ActiveRecord::Migration[7.1]
  def change
    create_table :kanban_calendar_availability_rules do |t|
      t.references :kanban_calendar_resource, null: false, foreign_key: true, index: false
      t.string :kind, null: false
      t.integer :weekday
      t.date :date
      t.time :starts_at_local
      t.time :ends_at_local
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :kanban_calendar_availability_rules,
              [:kanban_calendar_resource_id, :kind, :weekday],
              name: 'index_calendar_availability_rules_on_resource_kind_weekday'
    add_index :kanban_calendar_availability_rules,
              [:kanban_calendar_resource_id, :date],
              name: 'index_calendar_availability_rules_on_resource_date'
  end
end
