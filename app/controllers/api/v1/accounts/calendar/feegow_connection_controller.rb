# A ligação da clínica ao Feegow: token, validade e importação da agenda.
#
# O token nunca volta para o browser. O que volta é o estado e a validade, que é
# o que a tela precisa para avisar antes de vencer.
class Api::V1::Accounts::Calendar::FeegowConnectionController < Api::V1::Accounts::BaseController
  before_action :authorize_calendar_configuration

  def show
    render json: connection_payload
  end

  def update
    connection.update!(connection_params)
    render json: connection_payload
  end

  def destroy
    connection.update!(api_token: nil, token_expires_at: nil, status: 'disconnected', last_error: nil)
    # Desligado o Feegow, a agenda dele deixa de travar horários.
    KanbanCalendarExternalBusyBlock.where(
      account_id: Current.account.id,
      provider: KanbanCalendar::FeegowImportService::PROVIDER
    ).delete_all
    head :no_content
  end

  # «Sincronizar agora»: importa à espera, para a resposta dizer se o Feegow aceitou.
  def sync
    return render json: { message: 'Feegow is not connected' }, status: :unprocessable_entity if connection.api_token.blank?

    connection.update!(status: 'connected', last_error: nil)
    KanbanCalendar::FeegowImportService.new(connection: connection).perform!
    connection.reload
    render json: connection_payload
  rescue KanbanCalendar::FeegowApiError
    connection.reload
    render json: connection_payload, status: :unprocessable_entity
  end

  def professionals
    render json: KanbanCalendar::FeegowClient.new(connection: connection).professionals.map { |professional| professional_payload(professional) }
  rescue KanbanCalendar::FeegowApiError => e
    render json: { message: e.message }, status: :unprocessable_entity
  end

  private

  def authorize_calendar_configuration
    authorize KanbanCalendarResource, :configure?
  end

  def connection
    @connection ||= KanbanCalendarFeegowConnection.find_or_initialize_by(account_id: Current.account.id).tap(&:save!)
  end

  def connection_params
    permitted = params.require(:feegow_connection).permit(:api_url, :api_token, :token_expires_at)
    return permitted if permitted[:api_token].blank?

    permitted.merge(
      status: 'connected',
      last_error: nil,
      # Sem validade informada assume-se a que o Feegow pratica: 90 dias. Um
      # token sem prazo à vista é um token que vence sem ninguém perceber.
      token_expires_at: permitted[:token_expires_at].presence || KanbanCalendarFeegowConnection::DEFAULT_TOKEN_LIFETIME.from_now
    )
  end

  def professional_payload(professional)
    {
      id: (professional['profissional_id'] || professional['id']).to_s,
      name: professional['nome'] || professional['name']
    }
  end

  def connection_payload
    {
      connected: connection.connected?,
      status: connection.status,
      api_url: connection.api_url,
      has_token: connection.api_token.present?,
      token_expires_at: connection.token_expires_at,
      token_expires_in_days: token_expires_in_days,
      token_expired: connection.token_expired?,
      token_expiring_soon: connection.token_expiring_soon?,
      last_error: connection.last_error,
      last_imported_at: connection.last_imported_at
    }
  end

  def token_expires_in_days
    return if connection.token_expires_at.blank?

    ((connection.token_expires_at - Time.current) / 1.day).round
  end
end
