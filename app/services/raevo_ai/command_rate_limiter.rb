class RaevoAi::CommandRateLimiter
  LIMIT = 60
  PERIOD = 1.minute

  def initialize(integration:)
    @integration = integration
  end

  def allowed?
    Rails.cache.write(cache_key, 0, expires_in: PERIOD) unless Rails.cache.exist?(cache_key)
    (Rails.cache.increment(cache_key, 1) || 1) <= LIMIT
  end

  private

  def cache_key
    "raevo-ai-command:#{@integration.id}"
  end
end
