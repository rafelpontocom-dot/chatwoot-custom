# A ligação da conta ao Feegow. O token vence a cada 90 dias, por isso a validade
# é guardada e mostrada: sem ela, a agenda deixa de sincronizar em silêncio.
class CreateKanbanCalendarFeegowConnections < ActiveRecord::Migration[7.1]
  def change
    create_table :kanban_calendar_feegow_connections do |t|
      t.references :account, null: false, foreign_key: true, index: { unique: true }
      t.string :api_url, null: false, default: 'https://api.feegow.com/v1/api'
      t.string :api_token
      t.datetime :token_expires_at
      t.string :status, null: false, default: 'disconnected'
      t.text :last_error
      t.datetime :last_imported_at
      t.timestamps
    end
  end
end
