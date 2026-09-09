class AddExternalSourceToCalendarAppointments < ActiveRecord::Migration[7.1]
  def change
    change_table :kanban_calendar_appointments, bulk: true do |t|
      t.string :source_provider
      t.string :source_external_id
      t.boolean :source_read_only, null: false, default: false
      t.string :source_status
      t.datetime :source_updated_at
      t.datetime :source_synced_at
      t.string :source_hash
    end

    add_index :kanban_calendar_appointments,
              [:account_id, :source_provider, :source_external_id],
              unique: true,
              where: 'source_provider IS NOT NULL AND source_external_id IS NOT NULL',
              name: 'idx_calendar_appointments_on_external_source'
  end
end
