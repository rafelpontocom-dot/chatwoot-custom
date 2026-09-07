class Api::V1::Accounts::RaevoAi::AssistantDraftsController < Api::V1::Accounts::BaseController
  before_action :authorize_account

  def show
    integration = Current.account.raevo_ai_integration
    return render json: { error: 'raevo_ai_not_configured' }, status: :not_found unless integration

    result = RaevoAi::AssistantDraftClient.new(integration: integration).fetch
    render json: result.fetch(:response)
  rescue RaevoAi::ConfigurationError, RaevoAi::UpstreamError
    render json: { error: 'assistant_draft_unavailable' }, status: :service_unavailable
  end

  def update
    integration = Current.account.raevo_ai_integration
    return render json: { error: 'raevo_ai_not_configured' }, status: :not_found unless integration

    result = RaevoAi::AssistantDraftClient.new(integration: integration).save(
      editable_clusters: editable_clusters,
      expected_revision: params[:expected_revision].presence,
      actor_ref: "chatwoot:#{Current.account.id}:#{Current.user.id}"
    )
    render json: { draft: result.fetch(:response) }
  rescue ActionController::BadRequest, ActionController::ParameterMissing
    render json: { error: 'invalid_assistant_draft' }, status: :unprocessable_entity
  rescue RaevoAi::AssistantDraftClient::Conflict
    render json: { error: 'assistant_draft_conflict' }, status: :conflict
  rescue RaevoAi::ConfigurationError, RaevoAi::UpstreamError
    render json: { error: 'assistant_draft_unavailable' }, status: :service_unavailable
  end

  def simulate
    integration = Current.account.raevo_ai_integration
    return render json: { error: 'raevo_ai_not_configured' }, status: :not_found unless integration

    result = RaevoAi::AssistantDraftClient.new(integration: integration).simulate(**simulation_params)
    render json: result.fetch(:response)
  rescue ActionController::BadRequest, ActionController::ParameterMissing
    render json: { error: 'invalid_assistant_draft_simulation' }, status: :unprocessable_entity
  rescue RaevoAi::ConfigurationError, RaevoAi::UpstreamError
    render json: { error: 'assistant_draft_simulation_unavailable' }, status: :service_unavailable
  end

  def review
    integration = Current.account.raevo_ai_integration
    return render json: { error: 'raevo_ai_not_configured' }, status: :not_found unless integration

    result = RaevoAi::AssistantDraftClient.new(integration: integration).review(
      **review_params,
      actor_ref: "chatwoot:#{Current.account.id}:#{Current.user.id}"
    )
    render json: { review: result.fetch(:response) }
  rescue ActionController::BadRequest, ActionController::ParameterMissing
    render json: { error: 'invalid_assistant_draft_review' }, status: :unprocessable_entity
  rescue RaevoAi::AssistantDraftClient::Conflict
    render json: { error: 'assistant_draft_review_conflict' }, status: :conflict
  rescue RaevoAi::ConfigurationError, RaevoAi::UpstreamError
    render json: { error: 'assistant_draft_review_unavailable' }, status: :service_unavailable
  end

  def publish
    integration = Current.account.raevo_ai_integration
    return render json: { error: 'raevo_ai_not_configured' }, status: :not_found unless integration

    result = RaevoAi::AssistantDraftClient.new(integration: integration).publish(
      **publication_params,
      actor_ref: "chatwoot:#{Current.account.id}:#{Current.user.id}"
    )
    render json: { publication: result.fetch(:response) }
  rescue ActionController::BadRequest, ActionController::ParameterMissing
    render json: { error: 'invalid_assistant_draft_publication' }, status: :unprocessable_entity
  rescue RaevoAi::AssistantDraftClient::Conflict
    render json: { error: 'assistant_draft_publication_conflict' }, status: :conflict
  rescue RaevoAi::ConfigurationError, RaevoAi::UpstreamError
    render json: { error: 'assistant_draft_publication_unavailable' }, status: :service_unavailable
  end

  def rollback
    integration = Current.account.raevo_ai_integration
    return render json: { error: 'raevo_ai_not_configured' }, status: :not_found unless integration

    result = RaevoAi::AssistantDraftClient.new(integration: integration).rollback(
      **rollback_params,
      actor_ref: "chatwoot:#{Current.account.id}:#{Current.user.id}"
    )
    render json: { rollback: result.fetch(:response) }
  rescue ActionController::BadRequest, ActionController::ParameterMissing
    render json: { error: 'invalid_assistant_draft_rollback' }, status: :unprocessable_entity
  rescue RaevoAi::AssistantDraftClient::Conflict
    render json: { error: 'assistant_draft_rollback_conflict' }, status: :conflict
  rescue RaevoAi::ConfigurationError, RaevoAi::UpstreamError
    render json: { error: 'assistant_draft_rollback_unavailable' }, status: :service_unavailable
  end

  private

  def authorize_account
    authorize Current.account, :update?
  end

  def editable_clusters
    raw = params.require(:editable_clusters)
    allowed_clusters = %w[identity personality voice_style]
    raise ActionController::BadRequest unless raw.keys.map(&:to_s).sort == allowed_clusters.sort

    raw.to_unsafe_h.each_with_object({}) do |(key, value), output|
      fields = value.to_h.stringify_keys
      raise ActionController::BadRequest unless fields.keys.sort == %w[content enabled]

      output[key.to_s] = fields.slice('enabled', 'content')
    end
  end

  def simulation_params
    draft_id = params.require(:draft_id).to_s
    fixture_id = params.require(:fixture_id).to_s
    raise ActionController::BadRequest unless draft_id.match?(/\A[0-9a-f-]{36}\z/i)
    raise ActionController::BadRequest unless %w[first_contact scheduling_intent human_request].include?(fixture_id)

    { draft_id: draft_id, fixture_id: fixture_id }
  end

  def review_params
    simulation = simulation_params
    expected_revision = params.require(:expected_revision).to_s
    decision = params.require(:decision).to_s
    raise ActionController::BadRequest unless expected_revision.match?(/\A\d{4}-\d{2}-\d{2}T.+(?:Z|[+-]\d{2}:\d{2})\z/)
    raise ActionController::BadRequest unless %w[approved rejected].include?(decision)

    simulation.merge(expected_revision: expected_revision, decision: decision)
  end

  def publication_params
    draft_id = params.require(:draft_id).to_s
    expected_revision = params.require(:expected_revision).to_s
    expected_active_version_id = params[:expected_active_version_id].presence
    review_id = params.require(:review_id).to_s
    raise ActionController::BadRequest unless uuid?(draft_id) && uuid?(review_id)
    raise ActionController::BadRequest unless expected_active_version_id.nil? || uuid?(expected_active_version_id)
    raise ActionController::BadRequest unless expected_revision.match?(/\A\d{4}-\d{2}-\d{2}T.+(?:Z|[+-]\d{2}:\d{2})\z/)

    { draft_id: draft_id, expected_revision: expected_revision, expected_active_version_id: expected_active_version_id, review_id: review_id }
  end

  def rollback_params
    target_version_id = params.require(:target_version_id).to_s
    expected_active_version_id = params.require(:expected_active_version_id).to_s
    raise ActionController::BadRequest unless uuid?(target_version_id) && uuid?(expected_active_version_id)

    { target_version_id: target_version_id, expected_active_version_id: expected_active_version_id }
  end

  def uuid?(value)
    value.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
  end
end
