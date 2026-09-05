class CreateRaevoAiIntegrations < ActiveRecord::Migration[7.1]
  def change
    create_table :raevo_ai_integrations do |t|
      t.references :account, null: false, foreign_key: true, index: { unique: true }
      t.string :clinic_id, null: false
      t.boolean :enabled, null: false, default: false
      t.jsonb :settings, null: false, default: {}

      t.timestamps
    end

    add_index :raevo_ai_integrations, :clinic_id, unique: true
  end
end
