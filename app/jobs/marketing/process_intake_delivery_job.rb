class Marketing::ProcessIntakeDeliveryJob < ApplicationJob
  queue_as :default

  MAX_RETRIES = 3

  def perform(delivery_id)
    @delivery = MarketingWebhookDelivery.find_by(id: delivery_id, provider: 'intake')
    return if delivery.blank? || delivery.processing_status == 'processed'
    return delivery.mark_intake_failed!('source_unavailable') unless source_available?

    mark_processing!
    finish_processing(ingest)
  rescue JSON::ParserError
    delivery&.mark_intake_failed!('invalid_payload')
  end

  private

  attr_reader :delivery

  def source_available?
    delivery.marketing_intake_source&.active?
  end

  def mark_processing!
    delivery.update!(processing_status: 'processing', retry_count: delivery.retry_count + 1)
  end

  def ingest
    Marketing::IngestLeadService.new(
      source: delivery.marketing_intake_source,
      payload: JSON.parse(delivery.raw_payload)
    ).perform
  end

  def finish_processing(result)
    if result.ok?
      delivery.mark_intake_processed!(result)
    else
      delivery.mark_intake_failed!(result.error)
      retry_later(delivery) if delivery.retry_count < MAX_RETRIES && result.error == 'destination_unavailable'
    end
  end

  def retry_later(delivery)
    self.class.set(wait: (5 * (2**(delivery.retry_count - 1))).minutes).perform_later(delivery.id)
  end
end
