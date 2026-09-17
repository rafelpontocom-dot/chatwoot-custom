require 'rails_helper'

RSpec.describe KanbanCalendar::PublicBookingRateLimiter do
  let(:booking_page) { instance_double(KanbanCalendarBookingPage, id: 7) }
  let(:limiter) { described_class.new(booking_page: booking_page, remote_ip: '203.0.113.9') }

  around do |example|
    original = Rails.cache
    Rails.cache = ActiveSupport::Cache::FileStore.new(Rails.root.join('tmp/cache/rate-limiter-spec'))
    Rails.cache.clear
    example.run
  ensure
    Rails.cache = original
  end

  it 'allows ten attempts a minute and lets the same visitor try again the next minute' do
    travel_to(Time.zone.local(2026, 9, 17, 1, 30, 5)) do
      expect(Array.new(10) { limiter.allowed? }).to all(be(true))
      expect(limiter.allowed?).to be(false)
    end

    travel_to(Time.zone.local(2026, 9, 17, 1, 31, 5)) do
      expect(limiter.allowed?).to be(true)
    end
  end
end
