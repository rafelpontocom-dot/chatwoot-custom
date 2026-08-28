class CreateFinanceProviderConnections < ActiveRecord::Migration[7.1]
  def change
    create_table :finance_provider_connections do |t|
      t.references :account, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :environment, null: false, default: 'sandbox'
      t.string :api_key
      t.string :webhook_token
      t.string :provider_account_id
      t.string :display_name
      t.string :status, null: false, default: 'disconnected'
      t.text :last_error
      t.datetime :last_verified_at
      t.datetime :last_webhook_at
      t.jsonb :settings, null: false, default: {}
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end

    add_index :finance_provider_connections, [:account_id, :provider], unique: true
  end
end
