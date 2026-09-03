FactoryBot.define do
  factory :marketing_touchpoint do
    account
    contact { association(:contact, account: account) }
    conversation { nil }
    kanban_card { nil }
    source { 'widget_referer' }
    payload { { 'utm_source' => 'google', 'utm_medium' => 'cpc' } }
    occurred_at { Time.current }
    dedupe_digest { MarketingTouchpoint.digest_for('spec', SecureRandom.uuid) }
  end
end
