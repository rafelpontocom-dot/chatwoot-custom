require 'rails_helper'

RSpec.describe Forms::PhoneNumberNormalizer do
  it 'normalizes a local Brazilian number to E.164' do
    normalized = described_class.new(
      phone_number: '(11) 99999-9999',
      locale: 'pt_BR'
    ).call

    expect(normalized).to eq('+5511999999999')
  end

  it 'normalizes a local Portuguese number to E.164' do
    normalized = described_class.new(
      phone_number: '912 345 678',
      locale: 'pt_PT'
    ).call

    expect(normalized).to eq('+351912345678')
  end

  it 'does not infer a country for another locale' do
    normalized = described_class.new(
      phone_number: '11999999999',
      locale: 'en'
    ).call

    expect(normalized).to eq('11999999999')
  end
end
