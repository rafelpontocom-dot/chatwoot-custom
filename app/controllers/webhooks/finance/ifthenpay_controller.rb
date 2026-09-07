# ifthenpay calls this endpoint to confirm a settled payment. It authenticates
# with the merchant's anti-phishing key carried in the query string, and only
# reads the HTTP status of our reply: anything other than 200 is retried.
class Webhooks::Finance::IfthenpayController < ActionController::API
  before_action :verify_anti_phishing_key!

  def receive
    delivery = webhook_delivery
    event = Finance::Ifthenpay::ProcessCallbackService.new(connection: connection, params: callback_params).perform
    delivery.mark_processed!(status: event.processing_status)
    head :ok
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
    delivery ||= webhook_delivery
    delivery.mark_failed!(e)
    record_processing_failure(e)
    head :unprocessable_entity
  end

  private

  def connection
    @connection ||= FinanceProviderConnection.find_by!(id: params[:connection_id], provider: 'ifthenpay')
  end

  def verify_anti_phishing_key!
    expected = connection.webhook_token.to_s
    received = Finance::Ifthenpay::ProcessCallbackService.anti_phishing_key(callback_params).to_s
    valid = expected.present? && expected.bytesize == received.bytesize &&
            ActiveSupport::SecurityUtils.secure_compare(expected, received)
    head :unauthorized unless valid
  rescue ActiveRecord::RecordNotFound
    head :unauthorized
  end

  def callback_params
    request.query_parameters.merge(request.request_parameters).except('connection_id', 'controller', 'action')
  end

  def webhook_delivery
    Finance::WebhookDeliveryRecorder.new(
      connection: connection,
      raw_payload: callback_params.to_json,
      payload: callback_params
    ).perform
  end

  def record_processing_failure(error)
    connection.update!(status: 'attention', last_error: "Callback processing failed: #{error.class.name}")
  end
end
