class CreateFinanceCustomersAndPayments < ActiveRecord::Migration[7.1]
  # This migration creates the initial finance schema atomically.
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def change
    create_table :finance_customers do |t|
      t.references :account, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true
      t.references :finance_provider_connection, null: false, foreign_key: true
      t.string :provider_customer_id, null: false
      t.jsonb :provider_payload, null: false, default: {}
      t.datetime :last_synced_at

      t.timestamps
    end
    add_index :finance_customers,
              [:finance_provider_connection_id, :contact_id],
              unique: true,
              name: 'index_finance_customers_on_connection_and_contact'
    add_index :finance_customers,
              [:finance_provider_connection_id, :provider_customer_id],
              unique: true,
              name: 'index_finance_customers_on_connection_and_provider_customer'

    create_table :finance_payments do |t|
      t.references :account, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true
      t.references :kanban_card, foreign_key: true
      t.references :finance_customer, foreign_key: true
      t.references :finance_provider_connection, null: false, foreign_key: true
      t.string :provider_payment_id
      t.string :provider_customer_id
      t.string :external_reference, null: false
      t.string :kind, null: false, default: 'charge'
      t.string :status, null: false, default: 'draft'
      t.string :billing_type, null: false, default: 'undefined'
      t.integer :amount_cents, null: false
      t.string :currency, null: false, default: 'BRL'
      t.date :due_on
      t.datetime :paid_at
      t.text :invoice_url
      t.text :description
      t.jsonb :provider_payload, null: false, default: {}
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end
    add_index :finance_payments, [:account_id, :status]
    add_index :finance_payments, [:account_id, :kanban_card_id]
    add_index :finance_payments, [:account_id, :external_reference], unique: true
    add_index :finance_payments,
              [:finance_provider_connection_id, :provider_payment_id],
              unique: true,
              where: 'provider_payment_id IS NOT NULL',
              name: 'index_finance_payments_on_connection_and_provider_payment'

    create_table :finance_payment_events do |t|
      t.references :account, null: false, foreign_key: true
      t.references :finance_payment, null: false, foreign_key: true
      t.references :finance_provider_connection, null: false, foreign_key: true
      t.references :actor, foreign_key: { to_table: :users }
      t.string :provider_event_id
      t.string :event_type, null: false
      t.datetime :occurred_at, null: false
      t.string :processing_status, null: false, default: 'processed'
      t.text :error_message
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end
    add_index :finance_payment_events,
              [:finance_provider_connection_id, :provider_event_id],
              unique: true,
              where: 'provider_event_id IS NOT NULL',
              name: 'index_finance_payment_events_on_connection_and_provider_event'
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
end
