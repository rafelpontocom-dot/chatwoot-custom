class RaevoAi::ServiceHoursClient
  class Conflict < StandardError; end

  REQUEST_TIMEOUT_SECONDS = 10
  NETWORK_ERRORS = [Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED].freeze
  SOURCES = %w[structured legacy default].freeze

  def initialize(integration:)
    @integration = integration
  end

  def fetch
    validate_configuration!
    response = HTTParty.get(endpoint, headers: read_headers, timeout: REQUEST_TIMEOUT_SECONDS)
    raise RaevoAi::UpstreamError, 'Raevo AI service unavailable' unless response.success?

    config = sanitize_config(JSON.parse(response.body)['config'])
    raise RaevoAi::UpstreamError, 'Raevo AI service unavailable' unless config

    { response: config }
  rescue JSON::ParserError, *NETWORK_ERRORS
    raise RaevoAi::UpstreamError, 'Raevo AI service unavailable'
  end

  def save(config:, expected_revision:, actor_ref:)
    validate_configuration!
    response = HTTParty.put(endpoint, headers: write_headers(actor_ref), body: {
      expected_revision: expected_revision,
      config: config
    }.to_json, timeout: REQUEST_TIMEOUT_SECONDS)
    raise Conflict if conflict_response?(response)
    raise RaevoAi::UpstreamError, 'Raevo AI service unavailable' unless response.success?

    saved = sanitize_config(JSON.parse(response.body)['config'])
    raise RaevoAi::UpstreamError, 'Raevo AI service unavailable' unless saved

    { response: saved }
  rescue JSON::ParserError, *NETWORK_ERRORS
    raise RaevoAi::UpstreamError, 'Raevo AI service unavailable'
  end

  private

  def sanitize_config(value)
    return unless valid_config_shape?(value)
    return unless value['windows'].all? { |window| valid_window?(window) }
    return unless non_overlapping_schedule?(value['windows'])
    return unless valid_metadata?(value)

    value.slice('enabled', 'timezone', 'windows', 'revision', 'updated_at', 'source')
  end

  def valid_config_shape?(value)
    value.is_a?(Hash) &&
      [true, false].include?(value['enabled']) &&
      value['timezone'].is_a?(String) &&
      value['timezone'].length.between?(1, 64) &&
      value['windows'].is_a?(Array) &&
      value['windows'].length <= 28
  end

  def valid_metadata?(value)
    (value['revision'].nil? || value['revision'].is_a?(Integer)) &&
      (value['updated_at'].nil? || value['updated_at'].is_a?(String)) &&
      SOURCES.include?(value['source'])
  end

  def valid_window?(window)
    valid_window_shape?(window) && valid_days?(window['days']) && valid_clock_range?(window)
  end

  def valid_window_shape?(window)
    window.is_a?(Hash) && window['days'].is_a?(Array) && window['days'].any?
  end

  def valid_days?(days)
    days.all? { |day| day.is_a?(Integer) && day.between?(0, 6) }
  end

  def valid_clock_range?(window)
    window['start'].to_s.match?(/\A(?:[01]\d|2[0-3]):[0-5]\d\z/) &&
      window['end'].to_s.match?(/\A(?:[01]\d|2[0-3]):[0-5]\d\z/) &&
      window['start'] < window['end']
  end

  def non_overlapping_schedule?(windows)
    (0..6).all? do |day|
      periods = windows.select { |window| window['days'].include?(day) }.sort_by { |window| window['start'] }
      periods.each_cons(2).none? { |left, right| left['end'] > right['start'] }
    end
  end

  def conflict_response?(response)
    response.code == 409 && JSON.parse(response.body)['error'] == 'service_hours_config_conflict'
  rescue JSON::ParserError
    false
  end

  def validate_configuration!
    return if service_url.present? && service_token.present?

    raise RaevoAi::ConfigurationError, 'Raevo AI service is not configured'
  end

  def endpoint
    "#{service_url.delete_suffix('/')}/internal/chatwoot/service-hours"
  end

  def read_headers
    {
      'Accept' => 'application/json',
      'Authorization' => "Bearer #{service_token}",
      'X-Raevo-Clinic-Id' => @integration.clinic_id
    }
  end

  def write_headers(actor_ref)
    read_headers.merge(
      'Content-Type' => 'application/json',
      'X-Raevo-Actor-Ref' => actor_ref
    )
  end

  def service_url
    ENV.fetch('RAEVO_AI_SERVICE_URL', nil)
  end

  def service_token
    ENV.fetch('RAEVO_AI_SERVICE_TOKEN', nil)
  end
end
