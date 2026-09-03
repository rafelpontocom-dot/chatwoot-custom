require 'rails_helper'

RSpec.describe Marketing::AttributionFields do
  describe '.normalize' do
    it 'keeps only keys the marketing preset knows' do
      result = described_class.normalize('utm_source' => 'google', 'password' => 'secret', 'gclid' => 'abc')

      expect(result).to eq('utm_source' => 'google', 'gclid' => 'abc')
    end

    it 'accepts the key however the caller cased it' do
      expect(described_class.normalize('UTM_Source' => ' Google ')).to eq('utm_source' => 'Google')
    end

    it 'drops blanks so an empty parameter never becomes an empty field' do
      expect(described_class.normalize('utm_source' => '', 'utm_medium' => nil, 'gclid' => 'x')).to eq('gclid' => 'x')
    end

    it 'caps a value so a hostile caller cannot fill the jsonb' do
      result = described_class.normalize('utm_term' => 'a' * 2000)

      expect(result['utm_term'].length).to eq(described_class::MAX_VALUE_LENGTH)
    end

    it 'refuses nested structures' do
      expect(described_class.normalize('utm_source' => { evil: true }, 'gclid' => %w[a b])).to eq({})
    end

    it 'returns nothing for a blank input' do
      expect(described_class.normalize(nil)).to eq({})
    end
  end

  describe '.card_values' do
    it 'returns only what the opportunity tab can display' do
      attribution = { 'utm_source' => 'google', 'gclid' => 'abc', 'gbraid' => 'ios-click', 'msclkid' => 'bing' }

      expect(described_class.card_values(attribution)).to eq('utm_source' => 'google', 'gclid' => 'abc')
    end
  end

  it 'uses fbclid, the real name of the Meta click id' do
    expect(described_class::CARD_KEYS).to include('fbclid')
    expect(described_class::CARD_KEYS).not_to include('fvclid')
  end

  it 'captures the Google iOS click ids without putting them on the card' do
    expect(described_class::CONTACT_ONLY_KEYS).to include('gbraid', 'wbraid')
    expect(described_class::CARD_KEYS).not_to include('gbraid', 'wbraid')
  end
end
