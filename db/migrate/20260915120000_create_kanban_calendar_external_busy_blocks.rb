# Horários ocupados na agenda Google de quem ligou a sua agenda ao Raevo.
#
# Guarda só o intervalo, nunca o título nem a descrição: o que o médico tem na
# agenda pessoal não é da clínica, e basta saber que ele está ocupado para ninguém
# marcar por cima.
class CreateKanbanCalendarExternalBusyBlocks < ActiveRecord::Migration[7.1]
  def change
    create_table :kanban_calendar_external_busy_blocks do |t|
      t.references :account, null: false, foreign_key: true
      t.references :kanban_calendar_resource, null: false, foreign_key: true, index: false
      t.references :kanban_calendar_google_connection, null: false, foreign_key: true, index: false
      t.string :external_event_id, null: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.boolean :all_day, null: false, default: false
      t.timestamps
    end

    add_index :kanban_calendar_external_busy_blocks,
              [:kanban_calendar_google_connection_id, :external_event_id],
              unique: true,
              name: 'idx_calendar_busy_blocks_on_connection_event'
    add_index :kanban_calendar_external_busy_blocks,
              [:kanban_calendar_resource_id, :starts_at, :ends_at],
              name: 'idx_calendar_busy_blocks_on_resource_range'

    add_column :kanban_calendar_google_connections, :last_imported_at, :datetime
  end
end
