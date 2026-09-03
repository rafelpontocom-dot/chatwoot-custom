class Marketing::ProcessLeadgenEventJob < ApplicationJob
  queue_as :default

  def perform(delivery_id, event)
    delivery = MarketingWebhookDelivery.find_by(id: delivery_id)
    return if delivery.blank?

    Marketing::Meta::ProcessLeadgenEventService.new(delivery: delivery, event: event).perform
  end
end
