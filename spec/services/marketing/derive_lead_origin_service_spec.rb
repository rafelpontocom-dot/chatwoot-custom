require 'rails_helper'

RSpec.describe Marketing::DeriveLeadOriginService do
  # As duas chaves sao `select` no preset. Um valor fora das opcoes fica
  # gravado mas o campo aparece vazio na tela, por isso cada caso abaixo checa
  # um rotulo que existe de verdade na lista.
  def derive(attribution)
    described_class.new(attribution).perform
  end

  it 'reads a paid google click even when the campaign forgot the utms' do
    expect(derive('gclid' => 'abc')).to eq('origem_do_lead' => 'Mídia Paga', 'sub_origem' => '[MP] Google')
  end

  it 'reads the ios click ids as google too' do
    expect(derive('gbraid' => 'abc')['sub_origem']).to eq('[MP] Google')
    expect(derive('wbraid' => 'abc')['sub_origem']).to eq('[MP] Google')
  end

  it 'reads a paid meta click' do
    expect(derive('fbclid' => 'abc')).to eq('origem_do_lead' => 'Mídia Paga', 'sub_origem' => '[MP] Meta')
  end

  it 'trusts the click id over however the agency spelled the source' do
    result = derive('gclid' => 'abc', 'utm_source' => 'newsletter-do-parceiro')

    expect(result['sub_origem']).to eq('[MP] Google')
  end

  it 'treats a paid medium as paid even with no click id' do
    expect(derive('utm_source' => 'tiktok', 'utm_medium' => 'paid_social')['sub_origem']).to eq('[MP] TikTok')
  end

  it 'reads an organic source as organic' do
    expect(derive('utm_source' => 'instagram', 'utm_medium' => 'bio')).to eq(
      'origem_do_lead' => 'Orgânico', 'sub_origem' => '[ORG] Instagram'
    )
  end

  it 'calls a visit with no campaign at all direct' do
    expect(derive('landing_page' => 'https://c.com.br/')).to eq(
      'origem_do_lead' => 'Site', 'sub_origem' => '[ORG] Site Direto'
    )
  end

  it 'falls back to the unknown option instead of inventing a label' do
    result = derive('utm_source' => 'algum-parceiro-novo', 'utm_medium' => 'cpc')

    expect(result['sub_origem']).to eq('[OUT] Desconhecido')
  end

  it 'says nothing when it knows nothing' do
    expect(derive({})).to eq({})
  end
end
