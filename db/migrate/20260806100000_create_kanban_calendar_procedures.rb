class CreateKanbanCalendarProcedures < ActiveRecord::Migration[7.1]
  def change
    create_table :kanban_calendar_procedures do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :color
      t.integer :duration_minutes, null: false
      t.integer :buffer_before_minutes, null: false, default: 0
      t.integer :buffer_after_minutes, null: false, default: 0
      t.string :location_type, null: false, default: 'in_person'
      t.boolean :recurrence_allowed, null: false, default: false
      t.integer :max_sessions
      t.jsonb :allowed_intervals, null: false, default: []
      t.jsonb :board_ids, null: false, default: []
      t.jsonb :stage_policy, null: false, default: {}
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_procedure_name_index
  end

  private

  def add_procedure_name_index
    add_index :kanban_calendar_procedures,
              'account_id, lower(name)',
              unique: true,
              name: 'index_kanban_calendar_procedures_on_account_and_lower_name'
  end
end
