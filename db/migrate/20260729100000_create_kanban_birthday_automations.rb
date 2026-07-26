# rubocop:disable Metrics/AbcSize, Metrics/MethodLength
class CreateKanbanBirthdayAutomations < ActiveRecord::Migration[7.0]
  def change
    create_table :kanban_birthday_automations do |t|
      t.references :account, null: false, foreign_key: true, index: { unique: true }
      t.boolean :active, null: false, default: false
      t.integer :days_before, null: false, default: 0
      t.string :delivery_channels, array: true, null: false, default: []
      t.string :opt_in_attribute_key, null: false, default: 'birthday_messages_opt_in'
      t.string :timezone
      t.string :send_time, null: false, default: '09:00'
      t.text :message_template, null: false, default: 'Feliz aniversário, {{contact_name}}! Desejamos um dia especial para você.'
      t.jsonb :whatsapp_template_params, null: false, default: {}
      t.timestamps
    end

    create_table :kanban_birthday_deliveries do |t|
      t.references :account, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true
      t.references :kanban_birthday_automation,
                   null: false,
                   foreign_key: true,
                   index: { name: 'idx_birthday_deliveries_on_automation' }
      t.integer :birthday_year, null: false
      t.string :delivery_channel, null: false
      t.string :status, null: false, default: 'pending'
      t.bigint :message_id
      t.datetime :attempted_at
      t.datetime :sent_at
      t.datetime :skipped_at
      t.text :error_message
      t.timestamps
    end

    add_index :kanban_birthday_deliveries,
              [:account_id, :contact_id, :birthday_year, :delivery_channel],
              unique: true,
              name: 'idx_unique_kanban_birthday_deliveries'
    add_index :kanban_birthday_deliveries, [:account_id, :status, :created_at],
              name: 'idx_kanban_birthday_deliveries_processing'
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/MethodLength
