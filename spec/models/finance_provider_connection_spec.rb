require 'rails_helper'

RSpec.describe FinanceProviderConnection do
  let(:account) { create(:account) }

  it 'stores an Asaas credential without exposing it in the public payload' do
    connection = described_class.new(
      account: account,
      provider: 'asaas',
      environment: 'sandbox',
      api_key: 'asaas-sandbox-secret',
      status: 'pending'
    )

    expect(connection).to be_valid
    expect(connection.public_payload).not_to have_key(:api_key)
    expect(connection.public_payload).to include(provider: 'asaas', status: 'pending')
  end

  it 'rejects a provider that does not support the account market' do
    FinanceModuleSetting.create!(account: account, market: 'PT')

    connection = described_class.new(
      account: account,
      provider: 'asaas',
      environment: 'sandbox',
      api_key: 'asaas-sandbox-secret',
      status: 'pending'
    )

    expect(connection).not_to be_valid
    expect(connection.errors[:provider]).to be_present
  end

  it 'requires a strong, separate webhook token for Asaas' do
    connection = described_class.new(
      account: account,
      provider: 'asaas',
      environment: 'sandbox',
      api_key: 'asaas-sandbox-secret',
      webhook_token: 'short-token',
      status: 'pending'
    )

    expect(connection).not_to be_valid
    expect(connection.errors[:webhook_token]).to be_present
  end

  it 'allows a manual connection without provider credentials in Portugal' do
    FinanceModuleSetting.create!(account: account, market: 'PT', enabled: true)

    connection = described_class.new(
      account: account,
      provider: 'manual',
      environment: 'production',
      display_name: 'Registo externo',
      status: 'connected'
    )

    expect(connection).to be_valid
  end
end
