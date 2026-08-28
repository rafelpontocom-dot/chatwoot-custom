class Webhooks::Finance::AsaasController < ActionController::API
  before_action :verify_token!

  def receive
    payload = webhook_payload
    delivery = webhook_delivery(raw_payload: request.raw_post, payload: payload)
    event = Finance::Asaas::ProcessWebhookService.new(connection: connection, payload: payload).perform
    delivery.mark_processed!(status: event.processing_status)
    head :ok
  rescue JSON::ParserError, KeyError, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
    delivery ||= webhook_delivery(raw_payload: request.raw_post)
    delivery.mark_failed!(e)
    record_processing_failure(e)
    head :unprocessable_entity
  end

  private

  def connection
    @connection ||= FinanceProviderConnection.find_by!(id: params[:connection_id], provider: 'asaas')
  end

  def verify_token!
    expected_token = connection.webhook_token.to_s
    received_token = request.headers['asaas-access-token'].to_s
    valid = expected_token.present? && expected_token.bytesize == received_token.bytesize &&
            ActiveSupport::SecurityUtils.secure_compare(expected_token, received_token)
    head :unauthorized unless valid
  rescue ActiveRecord::RecordNotFound
    head :unauthorized
  end

  def webhook_payload
    @webhook_payload ||= JSON.parse(request.raw_post)
  end

  def webhook_delivery(raw_payload:, payload: nil)
    Finance::WebhookDeliveryRecorder.new(
      connection: connection,
      raw_payload: raw_payload,
      payload: payload
    ).perform
  end

  def record_processing_failure(error)
    connection.update!(status: 'attention', last_error: "Webhook processing failed: #{error.class.name}")
  end
end
