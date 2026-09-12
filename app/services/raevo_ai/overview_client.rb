class RaevoAi::OverviewClient
  REQUEST_TIMEOUT_SECONDS = 10
  NETWORK_ERRORS = [Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED].freeze
  PUBLIC_FIELDS = %w[status clinic_name package active_prompt_version knowledge_count open_reviews generated_at last_delivered_at
                     assistant_name
                     usage_window_days].freeze

  # As três janelas que o painel oferece. Fechada de propósito: um número vindo
  # do browser não deve escolher o alcance de uma varredura na base da clínica.
  WINDOW_DAYS = [7, 30, 90].freeze
  PUBLIC_ASSISTANT_PROFILE_FIELDS = %w[identity personality voice_style].freeze
  PUBLIC_OPERATIONAL_QUALITY_FIELDS = %w[
    post_delivery_actions_pending post_delivery_actions_applied post_delivery_actions_failed manual_reconciliations
  ].freeze
  PUBLIC_ATTENTION_LEVELS = %w[clear investigate action_required].freeze
  PUBLIC_ATTENTION_REASONS = %w[
    post_delivery_actions_failed post_delivery_actions_pending manual_reconciliations
  ].freeze
  PUBLIC_CAPABILITY_IDS = %w[atendimento crm agenda observabilidade].freeze
  PUBLIC_CAPABILITY_PROVIDERS = {
    'crm' => %w[chatwoot kommo],
    'agenda' => %w[calcom google_calendar feegow chatwoot_native]
  }.freeze
  PUBLIC_USAGE_FIELDS = %w[
    conversations responses_delivered first_response_seconds handoffs pre_scheduled appointments payments
    model_calls prompt_tokens completion_tokens
    provider_reported_cost_usd catalog_estimated_cost_usd cost_unavailable_calls
  ].freeze

  def initialize(integration:)
    @integration = integration
  end

  def fetch(window_days: 30)
    validate_configuration!

    response = HTTParty.get(endpoint(window_days), headers: headers, timeout: REQUEST_TIMEOUT_SECONDS)
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

  def endpoint(window_days)
    dias = WINDOW_DAYS.include?(window_days) ? window_days : 30
    "#{service_url.delete_suffix('/')}/internal/chatwoot/overview?days=#{dias}"
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

    # `usage_30d` é o nome antigo do runtime. Aceita-se os dois porque os dois
    # serviços implantam separadamente: durante o rollout um Chatwoot novo pode
    # falar com um runtime antigo, e o painel não deve ficar sem números por
    # isso. O recurso sai quando o runtime em produção já enviar `usage`.
    usage = payload['usage'] || payload['usage_30d']
    usage = {} unless usage.is_a?(Hash)

    sanitized = payload.slice(*PUBLIC_FIELDS).merge(
      'usage' => usage.slice(*PUBLIC_USAGE_FIELDS)
    )
    assistant_profile = sanitize_assistant_profile(payload['assistant_profile'])
    sanitized['assistant_profile'] = assistant_profile if assistant_profile
    operational_quality = sanitize_operational_quality(payload['operational_quality'])
    sanitized['operational_quality'] = operational_quality if operational_quality
    capabilities = sanitize_capabilities(payload['capabilities'])
    sanitized['capabilities'] = capabilities if capabilities
    sanitized
  end

  def sanitize_assistant_profile(value)
    return unless value.is_a?(Hash)

    value.slice(*PUBLIC_ASSISTANT_PROFILE_FIELDS).transform_values do |content|
      content.is_a?(String) ? content.slice(0, 500) : nil
    end
  end

  def sanitize_operational_quality(value)
    return unless value.is_a?(Hash)

    quality = value.slice(*PUBLIC_OPERATIONAL_QUALITY_FIELDS).transform_values do |count|
      count.is_a?(Integer) && count >= 0 ? count : 0
    end
    quality.merge!(sanitize_attention_level(value['attention_level']))
    quality.merge!(sanitize_attention_reasons(value['attention_reasons']))

    quality
  end

  def sanitize_attention_level(value)
    PUBLIC_ATTENTION_LEVELS.include?(value) ? { 'attention_level' => value } : {}
  end

  def sanitize_attention_reasons(value)
    return {} unless value.is_a?(Array)

    reasons = value.select { |reason| PUBLIC_ATTENTION_REASONS.include?(reason) }
                   .uniq.first(PUBLIC_ATTENTION_REASONS.length)
    { 'attention_reasons' => reasons }
  end

  def sanitize_capabilities(value)
    return unless value.is_a?(Hash)

    package = value['package']
    capabilities = sanitize_capability_items(value['capabilities'])
    return unless package.is_a?(String) && capabilities

    { 'package' => package.slice(0, 80), 'capabilities' => capabilities }
  end

  def sanitize_capability_items(value)
    return unless value.is_a?(Array)

    value.filter_map do |capability|
      next unless capability.is_a?(Hash)

      id = capability['id']
      provider = capability['provider']
      next unless PUBLIC_CAPABILITY_IDS.include?(id)
      next unless valid_capability_provider?(id, provider)

      { 'id' => id, 'provider' => provider }
    end.first(4)
  end

  def valid_capability_provider?(id, provider)
    return provider.nil? if %w[atendimento observabilidade].include?(id)

    PUBLIC_CAPABILITY_PROVIDERS.fetch(id, []).include?(provider)
  end
end
