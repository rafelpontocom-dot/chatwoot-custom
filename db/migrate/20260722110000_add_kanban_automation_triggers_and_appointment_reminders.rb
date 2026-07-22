# rubocop:disable Metrics/MethodLength, Metrics/AbcSize
class AddKanbanAutomationTriggersAndAppointmentReminders < ActiveRecord::Migration[7.1]
  def change
    add_column :kanban_cadences, :trigger_type, :string, null: false, default: 'manual'
    add_column :kanban_cadences, :trigger_stage_id, :bigint
    add_index :kanban_cadences, [:kanban_board_id, :trigger_type, :trigger_stage_id], name: 'idx_kanban_cadences_on_stage_trigger'
    add_foreign_key :kanban_cadences, :kanban_stages, column: :trigger_stage_id

    create_table :kanban_appointment_reminder_rules do |t|
      t.references :account, null: false, foreign_key: true
      t.references :kanban_board, null: false, foreign_key: true
      t.bigint :trigger_stage_id
      t.string :trigger_type, null: false, default: 'stage_entered'
      t.string :field_key, null: false
      t.jsonb :offsets, null: false, default: []
      t.jsonb :channels, null: false, default: []
      t.jsonb :message_templates, null: false, default: {}
      t.jsonb :whatsapp_template_params, null: false, default: {}
      t.string :opt_in_attribute_key, null: false, default: 'appointment_reminders_opt_in'
      t.string :timezone_mode, null: false, default: 'board'
      t.boolean :active, null: false, default: false
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_index :kanban_appointment_reminder_rules,
              [:kanban_board_id, :trigger_type, :trigger_stage_id],
              name: 'idx_kanban_appointment_rules_on_trigger'
    add_foreign_key :kanban_appointment_reminder_rules, :kanban_stages, column: :trigger_stage_id

    create_table :kanban_appointment_reminder_deliveries do |t|
      t.references :account, null: false, foreign_key: true
      t.references :kanban_board, null: false, foreign_key: true
      t.references :kanban_card, null: false, foreign_key: true
      t.references :kanban_appointment_reminder_rule, null: false, foreign_key: true, index: { name: 'idx_kanban_reminder_deliveries_on_rule' }
      t.string :appointment_version, null: false
      t.string :appointment_value, null: false
      t.integer :offset_hours, null: false
      t.string :delivery_channel, null: false
      t.datetime :scheduled_at, null: false
      t.datetime :attempted_at
      t.datetime :sent_at
      t.bigint :message_id
      t.string :status, null: false, default: 'scheduled'
      t.string :idempotency_key, null: false
      t.text :error_message
      t.timestamps
    end

    add_index :kanban_appointment_reminder_deliveries, :idempotency_key, unique: true, name: 'idx_kanban_reminder_deliveries_on_idempotency'
    add_index :kanban_appointment_reminder_deliveries, [:status, :scheduled_at], name: 'idx_kanban_reminder_deliveries_on_due'
    add_foreign_key :kanban_appointment_reminder_deliveries, :messages, column: :message_id
  end
end
# rubocop:enable Metrics/MethodLength, Metrics/AbcSize
