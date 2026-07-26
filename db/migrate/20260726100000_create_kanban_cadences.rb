# rubocop:disable Metrics/AbcSize, Metrics/MethodLength
class CreateKanbanCadences < ActiveRecord::Migration[7.1]
  def change
    create_table :kanban_cadences do |t|
      t.references :account, null: false, foreign_key: true
      t.references :kanban_board, null: false, foreign_key: true
      t.string :name, null: false
      t.jsonb :steps, null: false, default: []
      t.boolean :active, null: false, default: true
      t.boolean :pause_on_incoming_message, null: false, default: true
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_index :kanban_cadences, [:kanban_board_id, :name], unique: true
    add_index :kanban_cadences, [:account_id, :active]

    create_table :kanban_cadence_enrollments do |t|
      t.references :account, null: false, foreign_key: true
      t.references :kanban_board, null: false, foreign_key: true
      t.references :kanban_card, null: false, foreign_key: true
      t.references :kanban_cadence, null: false, foreign_key: true
      t.references :owner, foreign_key: { to_table: :users }
      t.integer :current_step, null: false, default: 0
      t.string :status, null: false, default: 'active'
      t.datetime :next_run_at
      t.datetime :started_at, null: false
      t.datetime :paused_at
      t.datetime :completed_at
      t.datetime :last_run_at
      t.text :last_error
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_index :kanban_cadence_enrollments,
              [:kanban_card_id, :kanban_cadence_id],
              unique: true,
              name: 'idx_kanban_cadence_enrollments_card_cadence'
    add_index :kanban_cadence_enrollments,
              [:status, :next_run_at],
              name: 'idx_kanban_cadence_enrollments_due'
    add_index :kanban_cadence_enrollments,
              [:account_id, :status],
              name: 'idx_kanban_cadence_enrollments_account_status'
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/MethodLength
