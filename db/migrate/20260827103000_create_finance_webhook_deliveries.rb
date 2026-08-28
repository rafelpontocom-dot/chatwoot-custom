class CreateFinanceWebhookDeliveries < ActiveRecord::Migration[7.1]
  def change
    create_table :finance_webhook_deliveries do |t|
      t.references :account, null: false, foreign_key: true
      t.references :finance_provider_connection, null: false, foreign_key: true
      t.string :provider_event_id
      t.string :payload_digest, null: false
      t.text :raw_payload, null: false
      t.string :processing_status, null: false, default: 'failed'
      t.text :error_message
      t.datetime :received_at, null: false
      t.datetime :processed_at
      t.integer :retry_count, null: false, default: 0

      t.timestamps
    end

    add_delivery_indexes
  end

  private

  def add_delivery_indexes
    add_index :finance_webhook_deliveries,
              [:finance_provider_connection_id, :provider_event_id],
              unique: true,
              where: 'provider_event_id IS NOT NULL',
              name: 'index_finance_webhook_deliveries_on_connection_and_event'
    add_index :finance_webhook_deliveries,
              [:finance_provider_connection_id, :payload_digest],
              unique: true,
              name: 'index_finance_webhook_deliveries_on_connection_and_digest'
    add_index :finance_webhook_deliveries,
              [:finance_provider_connection_id, :processing_status, :received_at],
              name: 'index_finance_webhook_deliveries_for_connection_status'
  end
end
