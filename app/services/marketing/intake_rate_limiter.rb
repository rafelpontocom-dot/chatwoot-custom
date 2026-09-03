class Marketing::IntakeRateLimiter
  # Escrita publica: um token vazado nao pode encher o CRM antes de alguem
  # perceber. Por token, nao por IP — o n8n de um cliente sai sempre do mesmo IP
  # e uma landing movimentada sai de milhares.
  LIMIT = 60
  PERIOD = 1.minute

  def initialize(source:)
    @source = source
  end

  def allowed?
    Rails.cache.write(cache_key, 0, expires_in: PERIOD) unless Rails.cache.exist?(cache_key)
    (Rails.cache.increment(cache_key, 1) || 1) <= LIMIT
  end

  private

  attr_reader :source

  def cache_key
    "marketing-intake:#{source.id}"
  end
end
