require 'rails_helper'

RSpec.describe Finance::Ifthenpay::VerifyConnectionService do
  let(:account) { create(:account) }
  let(:connection) do
    account.create_finance_module_setting!(enabled: true, market: 'PT')
    FinanceProviderConnection.create!(
      account: account, provider: 'ifthenpay', environment: 'production',
      api_key: '1111-1111-1111-1111', webhook_token: 'anti-phishing-key', status: 'pending',
      settings: { 'mbway_key' => 'ITP-000222' }
    )
  end

  it 'marks the connection connected when the backoffice key is accepted' do
    stub_request(:post, Finance::Ifthenpay::Client::LIST_PAYMENTS_URL).to_return(status: 200, body: '[]')

    described_class.new(connection: connection).perform

    expect(connection.reload).to have_attributes(status: 'connected', last_error: nil)
    expect(connection.last_verified_at).to be_present
  end

  it 'refuses to validate without an anti-phishing key, which settlements depend on' do
    connection.update!(webhook_token: nil)

    expect { described_class.new(connection: connection).perform }
      .to raise_error(Finance::Ifthenpay::ApiError, /anti-phishing key is required/)
    expect(connection.reload.status).to eq('error')
  end

  it 'records the gateway error when the key is rejected' do
    stub_request(:post, Finance::Ifthenpay::Client::LIST_PAYMENTS_URL)
      .to_return(status: 401, body: { Message: 'Invalid backoffice key' }.to_json)

    expect { described_class.new(connection: connection).perform }.to raise_error(Finance::Ifthenpay::ApiError)
    expect(connection.reload).to have_attributes(status: 'error', last_error: 'Invalid backoffice key')
  end
end
