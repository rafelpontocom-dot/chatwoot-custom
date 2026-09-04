class Api::V1::Accounts::Marketing::ConnectionsController < Api::V1::Accounts::BaseController
  before_action :ensure_marketing_module_enabled
  before_action :fetch_connection, only: [:destroy, :sync_pages, :subscribe_page, :sync_lead_forms]

  # `configure?`, nao `view?`: o /me/accounts do Meta devolve TODAS as paginas
  # que a pessoa administra. Numa agencia que atende varias clinicas, isso
  # inclui as paginas dos outros clientes — nao e coisa para a secretaria de
  # uma clinica enxergar.
  def index
    authorize MarketingProviderConnection, :configure?
    render json: { payload: connections.map(&:public_payload) }
  end

  def authorization_url
    authorize MarketingProviderConnection, :configure?
    render json: { url: Marketing::Meta::OauthService.new(account: Current.account).authorization_url }
  rescue Marketing::Meta::ApiError => e
    render json: { message: e.message }, status: :unprocessable_entity
  end

  # Desconectar zera o token e para de receber; os leads que ja entraram ficam.
  def destroy
    authorize MarketingProviderConnection, :configure?
    @connection.update!(access_token: nil, expires_at: nil, status: 'disconnected', settings: {})
    head :no_content
  end

  def sync_pages
    authorize MarketingProviderConnection, :configure?
    render json: { payload: @connection.reload.public_payload } if with_meta { sync_pages! }
  end

  def subscribe_page
    authorize MarketingProviderConnection, :configure?
    render json: { payload: @connection.reload.public_payload } if with_meta { toggle_subscription }
  end

  def sync_lead_forms
    authorize MarketingProviderConnection, :configure?
    forms = nil
    render json: { payload: forms.map(&:public_payload) } if with_meta { forms = sync_forms! }
  end

  private

  def connections
    Current.account.marketing_provider_connections
  end

  def fetch_connection
    @connection = connections.find(params[:id])
  end

  def sync_pages!
    Marketing::Meta::SyncPagesService.new(connection: @connection).perform
  end

  def toggle_subscription
    service = Marketing::Meta::SubscribePageService.new(connection: @connection, page_id: params.require(:page_id))
    ActiveModel::Type::Boolean.new.cast(params[:subscribed]) == false ? service.revoke : service.perform
  end

  def sync_forms!
    Marketing::Meta::SyncLeadFormsService.new(connection: @connection, page_id: params.require(:page_id)).perform
  end

  # O erro do Meta vira 422 com a classe, nunca com o texto do provedor.
  # `error_code` e a chave que a tela traduz no que a pessoa precisa ir arrumar.
  def with_meta
    yield
    true
  rescue Marketing::Meta::ApiError => e
    render json: { message: e.message, error_code: e.reason }, status: :unprocessable_entity
    false
  end

  def ensure_marketing_module_enabled
    return if Current.account.marketing_module_setting&.enabled?

    render json: { message: 'Marketing module is not enabled for this account' }, status: :forbidden
  end
end
