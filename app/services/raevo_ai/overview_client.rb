class RaevoAi::OverviewClient
  REQUEST_TIMEOUT_SECONDS = 10
  NETWORK_ERRORS = [Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED].freeze
  PUBLIC_FIELDS = %w[status clinic_name package active_prompt_version knowledge_count open_reviews].freeze
  PUBLIC_ASSISTANT_PROFILE_FIELDS = %w[identity personality voice_style].freeze
  PUBLIC_USAGE_FIELDS = %w[
    conversations handoffs appointments payments
    model_calls prompt_tokens completion_tokens
    provider_reported_cost_usd catalog_estimated_cost_usd cost_unavailable_calls
  ].freeze

  def initialize(integration:)
    @integration = integration
  end

  def fetch
    validate_configuration!

    response = HTTParty.get(endpoint, headers: headers, timeout: REQUEST_TIMEOUT_SECONDS)
    raise RaevoAi::UpstreamError, 'Raevo AI service unavailable' unless response.success?

    sanitize(JSON.parse(response.body))
  rescue JSON::ParserError, *NETWORK_ERRORS
    raise RaevoAi::UpstreamError, 'Raevo AI service unavailable'
  end

  private

  def validate_configuration!
    return if service_url.present? && service_token.present?

    raise RaevoAi::ConfigurationError, 'Raevo AI service is not configured'
  end

  def endpoint
    "#{service_url.delete_suffix('/')}/internal/chatwoot/overview"
  end

  def headers
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

  def sanitize(payload)
    raise RaevoAi::UpstreamError, 'Raevo AI service unavailable' unless payload.is_a?(Hash)

    usage = payload['usage_30d']
    usage = {} unless usage.is_a?(Hash)

    sanitized = payload.slice(*PUBLIC_FIELDS).merge(
      'usage_30d' => usage.slice(*PUBLIC_USAGE_FIELDS)
    )
    assistant_profile = sanitize_assistant_profile(payload['assistant_profile'])
    sanitized['assistant_profile'] = assistant_profile if assistant_profile
    sanitized
  end

  def sanitize_assistant_profile(value)
    return unless value.is_a?(Hash)

    value.slice(*PUBLIC_ASSISTANT_PROFILE_FIELDS).transform_values do |content|
      content.is_a?(String) ? content.slice(0, 500) : nil
    end
  end
end
