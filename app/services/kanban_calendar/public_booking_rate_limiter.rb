class KanbanCalendar::PublicBookingRateLimiter
  LIMIT_PER_MINUTE = 10

  def initialize(booking_page:, remote_ip:)
    @booking_page = booking_page
    @remote_ip = remote_ip
  end

  # Uma chave por minuto. O `increment` de alguns caches regrava a chave sem o
  # prazo; com o prazo na própria chave, um IP que passou do limite volta a
  # marcar no minuto seguinte em vez de ficar bloqueado para sempre.
  def allowed?
    key = "#{cache_key}:#{Time.current.to_i / 60}"
    count = Rails.cache.increment(key, 1, expires_in: 2.minutes)
    unless count
      Rails.cache.write(key, 1, expires_in: 2.minutes)
      count = 1
    end
    count <= LIMIT_PER_MINUTE
  end

  private

  attr_reader :booking_page, :remote_ip

  def cache_key
    "public-calendar-booking:#{booking_page.id}:#{remote_ip}"
  end
end
