class RaevoAi::AssistantDraftClient
  class Conflict < StandardError; end

  REQUEST_TIMEOUT_SECONDS = 10
  NETWORK_ERRORS = [Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED].freeze

  def initialize(integration:)
    @integration = integration
  end

  def save(editable_clusters:, expected_revision:, actor_ref:)
    validate_configuration!

    response = HTTParty.put(endpoint, headers: headers(actor_ref), body: {
      expected_revision: expected_revision,
      editable_clusters: editable_clusters
    }.to_json, timeout: REQUEST_TIMEOUT_SECONDS)
    raise Conflict if draft_conflict_response?(response)
    raise RaevoAi::UpstreamError, 'Raevo AI service unavailable' unless response.success?

    draft = sanitizer.draft(JSON.parse(response.body))
    raise RaevoAi::UpstreamError, 'Raevo AI service unavailable' unless draft

    { response: draft }
  rescue JSON::ParserError, *NETWORK_ERRORS
    raise RaevoAi::UpstreamError, 'Raevo AI service unavailable'
  end

  def fetch
    validate_configuration!

    response = HTTParty.get(endpoint, headers: read_headers, timeout: REQUEST_TIMEOUT_SECONDS)
    raise RaevoAi::UpstreamError, 'Raevo AI service unavailable' unless response.success?

    { response: sanitizer.read(JSON.parse(response.body)) }
  rescue JSON::ParserError, *NETWORK_ERRORS
    raise RaevoAi::UpstreamError, 'Raevo AI service unavailable'
  end

  def simulate(draft_id:, fixture_id:)
    validate_configuration!

    response = HTTParty.post(simulation_endpoint, headers: read_headers, body: {
      draft_id: draft_id,
      fixture_id: fixture_id
    }.to_json, timeout: REQUEST_TIMEOUT_SECONDS)
    raise RaevoAi::UpstreamError, 'Raevo AI service unavailable' unless response.success?

    simulation = sanitizer.simulation(JSON.parse(response.body))
    raise RaevoAi::UpstreamError, 'Raevo AI service unavailable' unless simulation

    { response: simulation }
  rescue JSON::ParserError, *NETWORK_ERRORS
    raise RaevoAi::UpstreamError, 'Raevo AI service unavailable'
  end

  def review(draft_id:, fixture_id:, expected_revision:, decision:, actor_ref:)
    validate_configuration!

    response = HTTParty.post(review_endpoint, headers: headers(actor_ref), body: {
      draft_id: draft_id,
      fixture_id: fixture_id,
      expected_revision: expected_revision,
      decision: decision
    }.to_json, timeout: REQUEST_TIMEOUT_SECONDS)
    raise Conflict if draft_review_conflict_response?(response)
    raise RaevoAi::UpstreamError, 'Raevo AI service unavailable' unless response.success?

    review = sanitizer.review(JSON.parse(response.body))
    raise RaevoAi::UpstreamError, 'Raevo AI service unavailable' unless review

    { response: review }
  rescue JSON::ParserError, *NETWORK_ERRORS
    raise RaevoAi::UpstreamError, 'Raevo AI service unavailable'
  end

  def publish(draft_id:, expected_revision:, expected_active_version_id:, review_id:, actor_ref:)
    validate_configuration!

    response = HTTParty.post(publication_endpoint, headers: headers(actor_ref), body: {
      draft_id: draft_id,
      expected_revision: expected_revision,
      expected_active_version_id: expected_active_version_id,
      review_id: review_id
    }.to_json, timeout: REQUEST_TIMEOUT_SECONDS)
    raise Conflict if draft_publication_conflict_response?(response)
    raise RaevoAi::UpstreamError, 'Raevo AI service unavailable' unless response.success?

    publication = sanitizer.publication(JSON.parse(response.body), 'publication')
    raise RaevoAi::UpstreamError, 'Raevo AI service unavailable' unless publication

    { response: publication }
  rescue JSON::ParserError, *NETWORK_ERRORS
    raise RaevoAi::UpstreamError, 'Raevo AI service unavailable'
  end

  def rollback(target_version_id:, expected_active_version_id:, actor_ref:)
    validate_configuration!

    response = HTTParty.post(rollback_endpoint, headers: headers(actor_ref), body: {
      target_version_id: target_version_id,
      expected_active_version_id: expected_active_version_id
    }.to_json, timeout: REQUEST_TIMEOUT_SECONDS)
    raise Conflict if draft_rollback_conflict_response?(response)
    raise RaevoAi::UpstreamError, 'Raevo AI service unavailable' unless response.success?

    rollback = sanitizer.publication(JSON.parse(response.body), 'rollback')
    raise RaevoAi::UpstreamError, 'Raevo AI service unavailable' unless rollback

    { response: rollback }
  rescue JSON::ParserError, *NETWORK_ERRORS
    raise RaevoAi::UpstreamError, 'Raevo AI service unavailable'
  end

  private

  def validate_configuration!
    return if service_url.present? && service_token.present?

    raise RaevoAi::ConfigurationError, 'Raevo AI service is not configured'
  end

  def endpoint
    "#{service_url.delete_suffix('/')}/internal/chatwoot/assistant-draft"
  end

  def simulation_endpoint
    "#{endpoint}/simulate"
  end

  def review_endpoint
    "#{endpoint}/review"
  end

  def publication_endpoint
    "#{endpoint}/publish"
  end

  def rollback_endpoint
    "#{endpoint}/rollback"
  end

  def headers(actor_ref)
    {
      'Accept' => 'application/json',
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{service_token}",
      'X-Raevo-Clinic-Id' => @integration.clinic_id,
      'X-Raevo-Actor-Ref' => actor_ref
    }
  end

  def read_headers
    {
      'Accept' => 'application/json',
      'Authorization' => "Bearer #{service_token}",
      'X-Raevo-Clinic-Id' => @integration.clinic_id
    }
  end

  def service_url
    ENV.fetch('RAEVO_AI_SERVICE_URL', nil)
  end

  def service_token
    ENV.fetch('RAEVO_AI_SERVICE_TOKEN', nil)
  end

  def sanitizer
    @sanitizer ||= RaevoAi::AssistantDraftResponseSanitizer.new
  end

  def draft_conflict_response?(response)
    return false unless response.code == 409

    JSON.parse(response.body)['error'] == 'assistant_draft_conflict'
  rescue JSON::ParserError
    false
  end

  def draft_review_conflict_response?(response)
    return false unless response.code == 409

    %w[assistant_draft_review_conflict assistant_draft_review_not_eligible].include?(JSON.parse(response.body)['error'])
  rescue JSON::ParserError
    false
  end

  def draft_publication_conflict_response?(response)
    return false unless response.code == 409

    %w[assistant_draft_publication_conflict assistant_draft_review_required].include?(JSON.parse(response.body)['error'])
  rescue JSON::ParserError
    false
  end

  def draft_rollback_conflict_response?(response)
    return false unless response.code == 409

    JSON.parse(response.body)['error'] == 'assistant_draft_rollback_conflict'
  rescue JSON::ParserError
    false
  end
end
