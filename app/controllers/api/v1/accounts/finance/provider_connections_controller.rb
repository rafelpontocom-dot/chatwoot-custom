class Api::V1::Accounts::Finance::ProviderConnectionsController < Api::V1::Accounts::BaseController
  before_action :ensure_finance_module_enabled
  before_action :fetch_connection, only: [:update, :destroy, :verify]

  def index
    authorize finance_module_setting, :view_payments?
    render json: policy_scope(FinanceProviderConnection).order(:provider).map(&:public_payload)
  end

  def create
    connection = Current.account.finance_provider_connections.new(connection_params)
    apply_initial_connection_status(connection)
    authorize connection, :configure?
    connection.save!
    render json: connection.public_payload, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { message: e.record.errors.full_messages.to_sentence, errors: e.record.errors }, status: :unprocessable_entity
  end

  def update
    authorize @connection, :configure?
    @connection.assign_attributes(connection_params)
    @connection.status = 'pending' if @connection.api_key.present? && @connection.status == 'disconnected'
    @connection.save!
    render json: @connection.public_payload
  rescue ActiveRecord::RecordInvalid => e
    render json: { message: e.record.errors.full_messages.to_sentence, errors: e.record.errors }, status: :unprocessable_entity
  end

  def destroy
    authorize @connection, :configure?
    @connection.update!(api_key: nil, webhook_token: nil, status: 'disconnected', last_error: nil)
    head :no_content
  end

  def verify
    authorize @connection, :configure?
    connection = Finance::Asaas::VerifyConnectionService.new(connection: @connection).perform
    render json: connection.public_payload
  rescue Finance::Asaas::ApiError => e
    render json: { message: e.message }, status: :unprocessable_entity
  end

  private

  def ensure_finance_module_enabled
    setting = Current.account.finance_module_setting
    return if setting&.enabled?

    render json: { message: 'Finance module is not enabled for this account' }, status: :forbidden
  end

  def finance_module_setting
    @finance_module_setting ||= Current.account.finance_module_setting || Current.account.build_finance_module_setting
  end

  def fetch_connection
    @connection = policy_scope(FinanceProviderConnection).find(params[:id])
  end

  def connection_params
    params.require(:provider_connection).permit(
      :provider,
      :environment,
      :api_key,
      :webhook_token,
      :display_name,
      :lock_version,
      settings: {}
    )
  end

  def apply_initial_connection_status(connection)
    connection.status = 'connected' if connection.provider == 'manual'
    connection.status = 'pending' if connection.api_key.present? && connection.status == 'disconnected'
  end
end
