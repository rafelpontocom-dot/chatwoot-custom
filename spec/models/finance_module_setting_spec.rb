require 'rails_helper'

RSpec.describe FinanceModuleSetting do
  let(:account) { create(:account) }

  it 'starts disabled and supports the Brazilian market' do
    setting = described_class.new(account: account)

    expect(setting).to be_valid
    expect(setting.enabled).to be(false)
    expect(setting.market).to eq('BR')
  end

  it 'keeps one finance module setting per account' do
    described_class.create!(account: account)

    duplicate = described_class.new(account: account)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:account_id]).to be_present
  end

  it 'only accepts providers available for the selected market' do
    setting = described_class.new(
      account: account,
      market: 'PT',
      default_payment_provider: 'asaas'
    )

    expect(setting).not_to be_valid
    expect(setting.errors[:default_payment_provider]).to be_present
  end
end
