class AddIntakeAuditLinksToMarketingWebhookDeliveries < ActiveRecord::Migration[7.1]
  def change
    add_reference :marketing_webhook_deliveries, :marketing_intake_source, foreign_key: true
    add_reference :marketing_webhook_deliveries, :contact, foreign_key: { on_delete: :nullify }
    add_reference :marketing_webhook_deliveries, :kanban_card, foreign_key: { on_delete: :nullify }
  end
end
