class Public::Api::V1::Marketing::IntakeController < ActionController::API
  # Entrada de leads de qualquer lugar: landing page, n8n, parceiro.
  #
  # `schema` existe para ninguem precisar perguntar "qual campo eu mando?" —
  # a integracao se descobre sozinha, que e a ideia boa do MCP sem o protocolo.
  before_action :authenticate_source!
  before_action :enforce_rate_limit!, only: [:create]

  def schema
    render json: {
      source: source.name,
      fields: {
        contact: %w[name email phone_number],
        opportunity: %w[subject],
        control: %w[idempotency_key],
        attribution: Marketing::AttributionFields::ALL_KEYS
      },
      notes: {
        identity: 'email or phone_number is required',
        idempotency: 'send idempotency_key to make a retry a no-op',
        max_value_length: Marketing::AttributionFields::MAX_VALUE_LENGTH
      }
    }
  end

  def create
    result = Marketing::IngestLeadService.new(source: source, payload: lead_params).perform

    if result.ok?
      render json: { status: result.status, contact_id: result.contact&.id, opportunity_id: result.kanban_card&.id },
             status: result.status == 'duplicate' ? :ok : :created
    else
      render json: { status: 'rejected', error: result.error }, status: :unprocessable_entity
    end
  end

  private

  def source
    @source ||= MarketingIntakeSource.authenticate(request.headers['X-Raevo-Intake-Token'])
  end

  # Token invalido, origem desligada e conta sem o modulo respondem igual: nao
  # se confirma a existencia de uma porta para quem nao tem a chave.
  def authenticate_source!
    return if source.present? && source.account.marketing_module_setting&.enabled?

    render json: { error: 'unauthorized' }, status: :unauthorized
  end

  def enforce_rate_limit!
    return if Marketing::IntakeRateLimiter.new(source: source).allowed?

    render json: { error: 'rate_limited' }, status: :too_many_requests
  end

  def lead_params
    params.permit(
      :name, :email, :phone_number, :subject, :idempotency_key,
      *Marketing::AttributionFields::ALL_KEYS.map(&:to_sym)
    ).to_h
  end
end
