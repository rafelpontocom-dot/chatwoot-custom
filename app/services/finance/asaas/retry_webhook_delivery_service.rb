class Finance::Asaas::RetryWebhookDeliveryService
  def initialize(delivery:)
    @delivery = delivery
  end

  def perform
    @delivery.with_lock do
      raise ActiveRecord::RecordInvalid, @delivery unless @delivery.processing_status == 'failed'

      event = Finance::Asaas::ProcessWebhookService.new(
        connection: @delivery.finance_provider_connection,
        payload: JSON.parse(@delivery.raw_payload)
      ).perform
      @delivery.increment_retry_count!
      @delivery.mark_processed!(status: event.processing_status)
    end
    @delivery
  rescue JSON::ParserError, KeyError, ActiveRecord::RecordNotFound => e
    @delivery.increment_retry_count!
    @delivery.mark_failed!(e)
    @delivery.finance_provider_connection.update!(status: 'attention', last_error: "Webhook processing failed: #{e.class.name}")
    raise
  end
end
