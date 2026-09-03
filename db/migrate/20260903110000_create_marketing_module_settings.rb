class CreateMarketingModuleSettings < ActiveRecord::Migration[7.1]
  # Opt-in por conta, no mesmo formato do Financeiro. Modulos do Raevo nao
  # entram em config/features.yml: quem decide e a conta, nao a instalacao.
  def change
    create_table :marketing_module_settings do |t|
      t.references :account, null: false, foreign_key: true, index: { unique: true }
      t.boolean :enabled, null: false, default: false
      t.datetime :enabled_at
      t.references :enabled_by, foreign_key: { to_table: :users }
      t.datetime :disabled_at
      t.references :disabled_by, foreign_key: { to_table: :users }
      t.jsonb :settings, null: false, default: {}
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end
  end
end
