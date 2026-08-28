require 'rails_helper'

RSpec.describe Finance::Asaas::VerifyConnectionService do
  let(:account) { create(:account) }
  let(:connection) do
    FinanceProviderConnection.create!(
      account: account,
      provider: 'asaas',
      environment: 'sandbox',
      api_key: 'asaas-test-key',
      status: 'pending'
    )
  end

  it 'marks the connection as connected after Asaas accepts the credential' do
    stub_request(:get, 'https://api-sandbox.asaas.com/v3/myAccount')
      .to_return(status: 200, body: { id: 'account_001', name: 'Clínica RAEVO' }.to_json)

    described_class.new(connection: connection).perform

    expect(connection.reload).to have_attributes(
      status: 'connected',
      provider_account_id: 'account_001',
      display_name: 'Clínica RAEVO',
      last_error: nil
    )
  end

  it 'records a provider error without losing the saved credential' do
    stub_request(:get, 'https://api-sandbox.asaas.com/v3/myAccount')
      .to_return(status: 401, body: { errors: [{ description: 'Credencial inválida' }] }.to_json)

    expect { described_class.new(connection: connection).perform }.to raise_error(Finance::Asaas::ApiError, 'Credencial inválida')

    expect(connection.reload).to have_attributes(status: 'error', last_error: 'Credencial inválida', api_key: 'asaas-test-key')
  end
end
