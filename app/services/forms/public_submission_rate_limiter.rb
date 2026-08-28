class Forms::PublicSubmissionRateLimiter
  def initialize(scope_record:, remote_ip:)
    @scope_record = scope_record
    @remote_ip = remote_ip
  end

  def allowed?
    Rails.cache.write(cache_key, 0, expires_in: 1.minute) unless Rails.cache.exist?(cache_key)
    (Rails.cache.increment(cache_key, 1) || 1) <= 10
  end

  private

  attr_reader :scope_record, :remote_ip

  def cache_key
    "public-form-submission:#{scope_record.class.name}:#{scope_record.id}:#{remote_ip}"
  end
end
