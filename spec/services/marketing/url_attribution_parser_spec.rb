require 'rails_helper'

RSpec.describe Marketing::UrlAttributionParser do
  it 'reads the campaign out of the query string the ad wrote' do
    url = 'https://clinica.com.br/lp?utm_source=google&utm_medium=cpc&utm_campaign=fue&gclid=ABC'

    result = described_class.new(url: url).perform

    expect(result).to include(
      'utm_source' => 'google',
      'utm_medium' => 'cpc',
      'utm_campaign' => 'fue',
      'gclid' => 'ABC'
    )
  end

  it 'separates the readable landing page from the full url' do
    url = 'https://clinica.com.br/lp/capilar?utm_source=google'

    result = described_class.new(url: url).perform

    expect(result['landing_page']).to eq('https://clinica.com.br/lp/capilar')
    expect(result['landing_page_full']).to eq(url)
  end

  it 'translates the names an advertiser types by hand into the preset keys' do
    url = 'https://c.com.br/?campaign_name=Inverno&adset_name=Mulheres&ad_name=Video1'

    expect(described_class.new(url: url).perform).to include(
      'campaign' => 'Inverno', 'adset' => 'Mulheres', 'ad' => 'Video1'
    )
  end

  it 'ignores everything the preset does not know' do
    result = described_class.new(url: 'https://c.com.br/?utm_source=google&session_token=secret').perform

    expect(result).not_to have_key('session_token')
  end

  it 'records the referrer when the caller knows it' do
    result = described_class.new(url: 'https://c.com.br/', referrer: 'https://google.com/').perform

    expect(result['referrer']).to eq('https://google.com/')
  end

  it 'returns nothing rather than raising for something that is not a url' do
    expect(described_class.new(url: 'not a url').perform).to eq({})
    expect(described_class.new(url: nil).perform).to eq({})
  end

  it 'refuses a non-http scheme' do
    expect(described_class.new(url: 'javascript:alert(1)').perform).to eq({})
  end
end
