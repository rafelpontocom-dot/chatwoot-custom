class AddPublicBookingProtections < ActiveRecord::Migration[7.1]
  def change
    add_column :kanban_calendar_booking_pages, :public_form_fields, :jsonb, default: [], null: false
    add_column :kanban_calendar_booking_pages, :captcha_provider, :string
    add_column :kanban_calendar_booking_pages, :captcha_site_key, :string

    create_table :kanban_calendar_booking_links do |t|
      t.references :account, null: false, foreign_key: true
      t.references :kanban_calendar_booking_page, null: false, foreign_key: true, index: { name: 'index_calendar_booking_links_on_page_id' }
      t.references :kanban_calendar_procedure, foreign_key: true
      t.string :token, null: false
      t.datetime :expires_at
      t.integer :max_uses
      t.integer :uses_count, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :kanban_calendar_booking_links, :token, unique: true
  end
end
