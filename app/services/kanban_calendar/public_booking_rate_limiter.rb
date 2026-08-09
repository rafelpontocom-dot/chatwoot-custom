class KanbanCalendar::PublicBookingRateLimiter
  def initialize(booking_page:, remote_ip:)
    @booking_page = booking_page
    @remote_ip = remote_ip
  end

  def allowed?
    Rails.cache.write(cache_key, 0, expires_in: 1.minute) unless Rails.cache.exist?(cache_key)
    (Rails.cache.increment(cache_key, 1) || 1) <= 10
  end

  private

  attr_reader :booking_page, :remote_ip

  def cache_key
    "public-calendar-booking:#{booking_page.id}:#{remote_ip}"
  end
end
