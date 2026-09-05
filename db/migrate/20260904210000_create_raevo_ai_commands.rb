class CreateRaevoAiCommands < ActiveRecord::Migration[7.1]
  def change
    create_table :raevo_ai_commands do |t|
      t.references :raevo_ai_integration, null: false, foreign_key: true, index: false
      t.string :action_id, null: false
      t.string :command_type, null: false
      t.string :payload_digest, null: false
      t.string :state, null: false, default: 'claimed'
      t.jsonb :result, null: false, default: {}

      t.timestamps
    end

    add_index :raevo_ai_commands,
              [:raevo_ai_integration_id, :action_id],
              unique: true,
              name: 'idx_raevo_ai_commands_on_integration_and_action'
  end
end
