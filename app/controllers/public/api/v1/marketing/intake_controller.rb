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
      fields: Marketing::IntakeContract.fields,
      notes: Marketing::IntakeContract.notes
    }
  end

  def create
    delivery = record_delivery
    result = Marketing::IngestLeadService.new(source: source, payload: lead_params).perform

    return render_success(delivery, result) if result.ok?

    render_failure(delivery, result)
  end

  private

  def source
    @source ||= MarketingIntakeSource.authenticate(request.headers[Marketing::IntakeContract::TOKEN_HEADER])
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

  def record_delivery
    Marketing::WebhookDeliveryRecorder.new(
      account: source.account,
      raw_payload: lead_params.to_json,
      provider_event_id: lead_params['idempotency_key'],
      provider: 'intake',
      marketing_intake_source: source
    ).perform
  end

  def retryable?(error)
    error == 'destination_unavailable'
  end

  def render_success(delivery, result)
    delivery.mark_intake_processed!(result)
    render json: {
      status: result.status, delivery_id: delivery.id,
      contact_id: result.contact&.id, opportunity_id: result.kanban_card&.id
    }, status: result.status == 'duplicate' ? :ok : :created
  end

  def render_failure(delivery, result)
    delivery.mark_intake_failed!(result.error)
    Marketing::ProcessIntakeDeliveryJob.set(wait: 1.minute).perform_later(delivery.id) if retryable?(result.error)
    render json: { status: 'rejected', delivery_id: delivery.id, error: result.error }, status: :unprocessable_entity
  end
end
