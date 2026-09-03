class CreateMarketingProviderConnections < ActiveRecord::Migration[7.1]
  # Conta de anuncio e muitos-por-plataforma, ao contrario do Financeiro: uma
  # clinica pode ter duas paginas do Meta. Por isso o unico e por conta +
  # plataforma + id externo, e nao por conta + plataforma.
  def change
    create_table :marketing_provider_connections do |t|
      t.references :account, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :external_account_id, null: false
      t.string :display_name
      t.string :status, null: false, default: 'disconnected'
      t.text :access_token
      t.datetime :expires_at
      t.string :last_error
      t.datetime :last_verified_at
      t.jsonb :settings, null: false, default: {}
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end

    add_index :marketing_provider_connections, [:account_id, :provider, :external_account_id],
              unique: true, name: 'index_marketing_connections_on_account_provider_and_external'
  end
end
