require 'rails_helper'

RSpec.describe Marketing::RecordTouchpointService do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:attribution) { { 'utm_source' => 'google', 'utm_campaign' => 'fue', 'gclid' => 'G1' } }

  context 'when the account has not enabled the module' do
    it 'records nothing at all' do
      expect do
        described_class.new(account: account, source: 'widget_referer', attribution: attribution, contact: contact).perform
      end.not_to change(MarketingTouchpoint, :count)
    end

    it 'leaves the contact untouched' do
      described_class.new(account: account, source: 'widget_referer', attribution: attribution, contact: contact).perform

      expect(contact.reload.additional_attributes).not_to have_key(described_class::ATTRIBUTION_KEY)
    end
  end

  context 'when the module is enabled' do
    before { account.create_marketing_module_setting!(enabled: true) }

    it 'records the touchpoint with the derived origin alongside the raw values' do
      touchpoint = described_class.new(
        account: account, source: 'widget_referer', attribution: attribution, contact: contact
      ).perform

      expect(touchpoint.payload).to include('gclid' => 'G1', 'origem_do_lead' => 'Mídia Paga')
      expect(touchpoint.source).to eq('widget_referer')
    end

    it 'answers the same touchpoint when the same event arrives twice' do
      first = described_class.new(account: account, source: 'widget_referer', attribution: attribution, contact: contact).perform
      second = described_class.new(account: account, source: 'widget_referer', attribution: attribution, contact: contact).perform

      expect(second.id).to eq(first.id)
      expect(MarketingTouchpoint.count).to eq(1)
    end

    it 'stores the first touch once and never rewrites it' do
      described_class.new(account: account, source: 'widget_referer', attribution: attribution, contact: contact).perform
      described_class.new(
        account: account, source: 'widget_referer', contact: contact,
        attribution: { 'utm_source' => 'instagram', 'utm_medium' => 'bio' }, dedupe_parts: %w[second touch]
      ).perform

      stored = contact.reload.additional_attributes[described_class::ATTRIBUTION_KEY]
      expect(stored['first_touch']['utm_source']).to eq('google')
      expect(stored['last_touch']['utm_source']).to eq('instagram')
    end

    it 'records nothing when there is no attribution to record' do
      expect do
        described_class.new(
          account: account, source: 'widget_referer', attribution: { 'irrelevant' => 'x' }, contact: contact
        ).perform
      end.not_to change(MarketingTouchpoint, :count)
    end

    it 'can record a touch that has no contact yet' do
      touchpoint = described_class.new(
        account: account, source: 'click_link', attribution: attribution, dedupe_parts: %w[anonymous 1]
      ).perform

      expect(touchpoint.contact_id).to be_nil
    end
  end
end
