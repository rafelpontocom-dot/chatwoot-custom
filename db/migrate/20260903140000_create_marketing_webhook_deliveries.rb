class CreateMarketingWebhookDeliveries < ActiveRecord::Migration[7.1]
  # O Meta reentrega. Sem uma linha por evento, uma reentrega vira um segundo
  # paciente na etapa de entrada.
  def change
    create_table :marketing_webhook_deliveries do |t|
      t.references :account, null: false, foreign_key: true
      t.string :provider, null: false, default: 'meta'
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
    add_index :marketing_webhook_deliveries, [:account_id, :provider_event_id],
              unique: true, where: 'provider_event_id IS NOT NULL',
              name: 'index_marketing_deliveries_on_account_and_event'
    add_index :marketing_webhook_deliveries, [:account_id, :payload_digest],
              unique: true, name: 'index_marketing_deliveries_on_account_and_digest'
    add_index :marketing_webhook_deliveries, [:account_id, :processing_status, :received_at],
              name: 'index_marketing_deliveries_for_account_status'
  end
end
