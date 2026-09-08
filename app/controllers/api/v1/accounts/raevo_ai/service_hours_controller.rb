class Api::V1::Accounts::RaevoAi::ServiceHoursController < Api::V1::Accounts::BaseController
  before_action :authorize_account

  def show
    integration = Current.account.raevo_ai_integration
    return render json: { error: 'raevo_ai_not_configured' }, status: :not_found unless integration

    result = RaevoAi::ServiceHoursClient.new(integration: integration).fetch
    render json: { config: result.fetch(:response) }
  rescue RaevoAi::ConfigurationError, RaevoAi::UpstreamError
    render json: { error: 'service_hours_config_unavailable' }, status: :service_unavailable
  end

  def update
    integration = Current.account.raevo_ai_integration
    return render json: { error: 'raevo_ai_not_configured' }, status: :not_found unless integration

    config = service_hours_config
    result = RaevoAi::ServiceHoursClient.new(integration: integration).save(
      config: config,
      expected_revision: expected_revision,
      actor_ref: "chatwoot:#{Current.account.id}:#{Current.user.id}"
    )
    render json: { config: result.fetch(:response) }
  rescue ActionController::BadRequest, ActionController::ParameterMissing
    render json: { error: 'invalid_service_hours_config' }, status: :unprocessable_entity
  rescue RaevoAi::ServiceHoursClient::Conflict
    render json: { error: 'service_hours_config_conflict' }, status: :conflict
  rescue RaevoAi::ConfigurationError, RaevoAi::UpstreamError
    render json: { error: 'service_hours_config_unavailable' }, status: :service_unavailable
  end

  private

  def authorize_account
    authorize Current.account, :update?
  end

  def expected_revision
    value = params[:expected_revision]
    return if value.nil?

    revision = Integer(value, exception: false)
    raise ActionController::BadRequest unless revision&.positive?

    revision
  end

  def service_hours_config
    raw = params.require(:config).to_unsafe_h.stringify_keys
    raise ActionController::BadRequest unless raw.keys.sort == %w[enabled timezone windows]

    validate_service_hours_header!(raw)
    windows = validated_windows(raw['windows'])

    { 'enabled' => raw['enabled'], 'timezone' => raw['timezone'], 'windows' => windows }
  end

  def validate_service_hours_header!(raw)
    raise ActionController::BadRequest unless [true, false].include?(raw['enabled'])
    raise ActionController::BadRequest unless valid_timezone?(raw['timezone'])
    raise ActionController::BadRequest unless valid_windows_collection?(raw['windows'])
    raise ActionController::BadRequest if raw['enabled'] && raw['windows'].empty?
  end

  def valid_timezone?(timezone)
    timezone.is_a?(String) && timezone.length.between?(1, 64)
  end

  def valid_windows_collection?(windows)
    windows.is_a?(Array) && windows.length <= 28
  end

  def validated_windows(raw_windows)
    windows = raw_windows.map do |window|
      raise ActionController::BadRequest unless window.respond_to?(:to_h)

      fields = window.to_h.stringify_keys
      raise ActionController::BadRequest unless fields.keys.sort == %w[days end start]

      normalized = normalized_window(fields)
      raise ActionController::BadRequest unless valid_window?(normalized)

      normalized
    end
    raise ActionController::BadRequest unless non_overlapping_schedule?(windows)

    windows
  end

  def normalized_window(fields)
    {
      'days' => Array(fields['days']).map { |day| Integer(day, exception: false) },
      'start' => fields['start'].to_s,
      'end' => fields['end'].to_s
    }
  end

  def valid_window?(window)
    window['days'].any? && window['days'].all? { |day| day&.between?(0, 6) } &&
      window['start'].match?(/\A(?:[01]\d|2[0-3]):[0-5]\d\z/) &&
      window['end'].match?(/\A(?:[01]\d|2[0-3]):[0-5]\d\z/) &&
      window['start'] < window['end']
  end

  def non_overlapping_schedule?(windows)
    (0..6).all? do |day|
      periods = windows.select { |window| window['days'].include?(day) }.sort_by { |window| window['start'] }
      periods.each_cons(2).none? { |left, right| left['end'] > right['start'] }
    end
  end
end
