class CreateMarketingIntakeSources < ActiveRecord::Migration[7.1]
  # Uma porta de entrada de leads por origem, nao por cliente: o lead precisa
  # cair num quadro e numa etapa, e a clinica vai querer "Lead Ads" num lugar e
  # "site" noutro. Sem indice unico por conta, ter varias nao custa nada.
  def change
    create_table :marketing_intake_sources do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :token, null: false
      t.jsonb :crm_destination, null: false, default: {}
      t.boolean :active, null: false, default: true
      t.datetime :last_received_at
      t.integer :received_count, null: false, default: 0

      t.timestamps
    end

    add_index :marketing_intake_sources, :token, unique: true
    add_index :marketing_intake_sources, [:account_id, :name], unique: true
  end
end
