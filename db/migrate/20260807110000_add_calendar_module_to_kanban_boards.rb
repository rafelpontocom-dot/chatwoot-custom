class AddCalendarModuleToKanbanBoards < ActiveRecord::Migration[7.1]
  def change
    add_column :kanban_boards, :calendar_enabled, :boolean, null: false, default: false
    add_column :kanban_boards, :calendar_booking_stage_ids, :jsonb, null: false, default: []
    add_column :kanban_boards, :calendar_procedure_ids, :jsonb, null: false, default: []
    add_column :kanban_boards, :calendar_legacy_next_appointment_field_key, :string
  end
end
