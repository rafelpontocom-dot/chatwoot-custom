class Api::V1::Accounts::Marketing::IntakeDeliveriesController < Api::V1::Accounts::BaseController
  before_action :ensure_marketing_module_enabled
  before_action :fetch_delivery, only: :retry

  def index
    authorize MarketingIntakeSource, :view?
    records = deliveries.includes(:marketing_intake_source).order(received_at: :desc, id: :desc)
    records = records.where(processing_status: params[:status]) if valid_status_filter?
    records = records.limit(limit)

    render json: { payload: records.map(&:public_payload) }
  end

  def retry
    authorize MarketingIntakeSource, :configure?
    return render_invalid_retry unless @delivery.processing_status == 'failed'

    @delivery.update!(processing_status: 'received', error_message: nil)
    Marketing::ProcessIntakeDeliveryJob.perform_later(@delivery.id)
    render json: { status: 'accepted', delivery_id: @delivery.id }, status: :accepted
  end

  private

  def deliveries
    Current.account.marketing_webhook_deliveries.where(provider: 'intake')
  end

  def fetch_delivery
    @delivery = deliveries.find(params[:id])
  end

  def valid_status_filter?
    params[:status].present? && MarketingWebhookDelivery::PROCESSING_STATUSES.include?(params[:status])
  end

  def limit
    params.fetch(:limit, 50).to_i.clamp(1, 100)
  end

  def render_invalid_retry
    render json: { message: 'Only failed intakes can be retried' }, status: :unprocessable_entity
  end

  def ensure_marketing_module_enabled
    return if Current.account.marketing_module_setting&.enabled?

    render json: { message: 'Marketing module is not enabled for this account' }, status: :forbidden
  end
end
