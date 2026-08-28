class Api::V1::Accounts::Finance::WebhookDeliveriesController < Api::V1::Accounts::BaseController
  before_action :ensure_finance_module_enabled
  before_action :fetch_connection

  def index
    authorize @connection, :configure?
    deliveries = @connection.finance_webhook_deliveries.order(received_at: :desc).limit(20)
    render json: deliveries.map(&:public_payload)
  end

  def retry
    authorize @connection, :configure?
    delivery = @connection.finance_webhook_deliveries.find(params[:id])
    Finance::Asaas::RetryWebhookDeliveryService.new(delivery: delivery).perform
    render json: delivery.public_payload
  rescue JSON::ParserError, KeyError, ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid => e
    render json: { message: "Webhook processing failed: #{e.class.name}" }, status: :unprocessable_entity
  end

  private

  def ensure_finance_module_enabled
    return if Current.account.finance_module_setting&.enabled?

    render json: { message: 'Finance module is not enabled for this account' }, status: :forbidden
  end

  def fetch_connection
    @connection = policy_scope(FinanceProviderConnection).find(params[:provider_connection_id])
  end
end
