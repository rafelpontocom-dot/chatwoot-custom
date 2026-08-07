class CreateKanbanCalendarAppointments < ActiveRecord::Migration[7.1]
  def change
    enable_extension 'btree_gist'
    create_procedure_resources
    create_appointment_series
    create_appointments
    create_appointment_resources
    add_overlap_constraint
    create_appointment_events
  end

  private

  def create_procedure_resources
    create_table :kanban_calendar_procedure_resources do |t|
      t.references :kanban_calendar_procedure, null: false, foreign_key: true, index: false
      t.references :kanban_calendar_resource, null: false, foreign_key: true, index: false

      t.timestamps
    end

    add_index :kanban_calendar_procedure_resources,
              [:kanban_calendar_procedure_id, :kanban_calendar_resource_id],
              unique: true,
              name: 'index_calendar_procedure_resources_on_procedure_and_resource'
  end

  def create_appointment_series
    create_table :kanban_calendar_appointment_series do |t|
      t.references :account, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true
      t.references :kanban_card, foreign_key: true
      t.references :kanban_calendar_procedure, null: false, foreign_key: true, index: false
      t.string :status, null: false, default: 'active'
      t.integer :planned_count, null: false, default: 1
      t.string :interval_kind, null: false, default: 'once'
      t.integer :interval_days
      t.string :timezone, null: false
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.jsonb :metadata, null: false, default: {}
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end

    add_index :kanban_calendar_appointment_series,
              [:account_id, :contact_id, :status],
              name: 'index_calendar_appointment_series_on_account_contact_status'
  end

  def create_appointments
    create_appointments_table
    add_appointment_indexes
  end

  def create_appointments_table
    create_table :kanban_calendar_appointments do |t|
      add_appointment_relationship_columns(t)
      add_appointment_state_columns(t)
      t.timestamps
    end
  end

  def add_appointment_relationship_columns(table)
    table.references :account, null: false, foreign_key: true
    table.references :kanban_calendar_appointment_series, null: false, foreign_key: true, index: false
    table.references :contact, null: false, foreign_key: true
    table.references :kanban_card, foreign_key: true
    table.references :kanban_calendar_procedure, null: false, foreign_key: true, index: false
    table.references :rescheduled_from, foreign_key: { to_table: :kanban_calendar_appointments }
    table.references :canceled_by, foreign_key: { to_table: :users }
  end

  def add_appointment_state_columns(table)
    table.string :status, null: false, default: 'scheduled'
    table.datetime :starts_at, null: false
    table.datetime :ends_at, null: false
    table.string :timezone, null: false
    table.integer :occurrence_number, null: false, default: 1
    table.integer :appointment_version, null: false, default: 1
    table.datetime :canceled_at
    table.string :cancellation_reason
    table.datetime :completed_at
    table.datetime :no_show_at
    table.text :notes
    table.jsonb :external_refs, null: false, default: {}
    table.integer :lock_version, null: false, default: 0
  end

  def add_appointment_indexes
    add_index :kanban_calendar_appointments,
              [:kanban_calendar_appointment_series_id, :occurrence_number],
              unique: true,
              name: 'index_calendar_appointments_on_series_and_occurrence'
    add_index :kanban_calendar_appointments,
              [:account_id, :starts_at, :status],
              name: 'index_calendar_appointments_on_account_starts_status'
  end

  def create_appointment_resources
    create_table :kanban_calendar_appointment_resources do |t|
      t.references :kanban_calendar_appointment, null: false, foreign_key: true, index: false
      t.references :kanban_calendar_resource, null: false, foreign_key: true, index: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :appointment_status, null: false

      t.timestamps
    end

    add_index :kanban_calendar_appointment_resources,
              [:kanban_calendar_appointment_id, :kanban_calendar_resource_id],
              unique: true,
              name: 'index_calendar_appointment_resources_on_appointment_resource'
    add_index :kanban_calendar_appointment_resources,
              [:kanban_calendar_resource_id, :starts_at, :ends_at],
              name: 'index_calendar_appointment_resources_on_resource_and_range'
  end

  def add_overlap_constraint
    reversible do |direction|
      direction.up do
        execute <<~SQL.squish
          ALTER TABLE kanban_calendar_appointment_resources
          ADD CONSTRAINT exclude_calendar_resource_appointment_overlaps
          EXCLUDE USING gist (
            kanban_calendar_resource_id WITH =,
            tsrange(starts_at, ends_at, '[)') WITH &&
          )
          WHERE (appointment_status IN ('scheduled', 'confirmed', 'checked_in'))
        SQL
      end

      direction.down do
        execute 'ALTER TABLE kanban_calendar_appointment_resources DROP CONSTRAINT exclude_calendar_resource_appointment_overlaps'
      end
    end
  end

  def create_appointment_events
    create_table :kanban_calendar_appointment_events do |t|
      t.references :account, null: false, foreign_key: true
      t.references :kanban_calendar_appointment, null: false, foreign_key: true, index: false
      t.references :actor, foreign_key: { to_table: :users }
      t.string :event_type, null: false
      t.datetime :occurred_at, null: false
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :kanban_calendar_appointment_events,
              [:kanban_calendar_appointment_id, :occurred_at],
              name: 'index_calendar_appointment_events_on_appointment_and_time'
  end
end
