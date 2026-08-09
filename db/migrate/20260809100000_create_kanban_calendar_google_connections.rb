class CreateKanbanCalendarGoogleConnections < ActiveRecord::Migration[7.1]
  def change
    create_table :kanban_calendar_google_connections do |t|
      t.references :account, null: false, foreign_key: true
      t.references :kanban_calendar_resource, null: false, foreign_key: true, index: { unique: true }
      t.string :access_token
      t.string :refresh_token
      t.datetime :expires_at
      t.string :calendar_id, null: false, default: 'primary'
      t.string :status, null: false, default: 'disconnected'
      t.text :last_error
      t.datetime :last_synced_at

      t.timestamps
    end
  end
end
