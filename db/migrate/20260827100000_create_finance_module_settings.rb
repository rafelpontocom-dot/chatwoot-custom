class CreateFinanceModuleSettings < ActiveRecord::Migration[7.1]
  def change
    create_table :finance_module_settings do |t|
      t.references :account, null: false, foreign_key: true, index: { unique: true }
      t.boolean :enabled, null: false, default: false
      t.string :market, null: false, default: 'BR'
      t.string :default_payment_provider
      t.string :default_invoicing_provider
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
