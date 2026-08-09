class AddPublicBookingToKanbanCalendar < ActiveRecord::Migration[7.1]
  def change
    add_procedure_publication_fields
    create_booking_pages
  end

  private

  def add_procedure_publication_fields
    add_column :kanban_calendar_procedures, :public_booking_enabled, :boolean, default: false, null: false
    add_column :kanban_calendar_procedures, :public_title, :string
    add_column :kanban_calendar_procedures, :public_description, :text
    add_column :kanban_calendar_procedures, :public_slug, :string
    add_column :kanban_calendar_procedures, :public_booking_config, :jsonb, default: {}, null: false
    add_index :kanban_calendar_procedures,
              'account_id, lower(public_slug)',
              unique: true,
              where: 'public_slug IS NOT NULL',
              name: 'index_calendar_procedures_on_account_and_public_slug'
  end

  def create_booking_pages
    create_table :kanban_calendar_booking_pages do |t|
      t.references :account, null: false, foreign_key: true, index: { unique: true }
      t.references :kanban_board, foreign_key: true
      t.references :kanban_stage, foreign_key: true
      t.references :inbox, foreign_key: true
      t.string :public_token, null: false
      t.string :title
      t.text :description
      t.string :duplicate_policy, null: false, default: 'create_new'
      t.integer :minimum_notice_minutes, null: false, default: 1440
      t.integer :maximum_notice_days, null: false, default: 60
      t.integer :slot_interval_minutes, null: false, default: 15
      t.boolean :active, null: false, default: false
      t.timestamps
    end
    add_index :kanban_calendar_booking_pages, :public_token, unique: true
  end
end
