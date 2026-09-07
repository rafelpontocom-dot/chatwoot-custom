require 'rails_helper'

RSpec.describe 'ifthenpay finance callback', type: :request do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:connection) do
    account.create_finance_module_setting!(enabled: true, market: 'PT')
    FinanceProviderConnection.create!(
      account: account, provider: 'ifthenpay', environment: 'production',
      api_key: '1111-1111-1111-1111', webhook_token: 'anti-phishing-key', status: 'connected',
      settings: { 'mb_key' => 'ITP-000111' }
    )
  end
  let!(:payment) do
    FinancePayment.create!(
      account: account, contact: contact, finance_provider_connection: connection,
      provider_payment_id: 'req_mb_1', external_reference: 'itp-abc123',
      amount_cents: 15_025, currency: 'EUR', billing_type: 'multibanco', status: 'pending'
    )
  end
  let(:url) { "/webhooks/finance/ifthenpay/#{connection.id}" }
  let(:valid_query) do
    { key: 'anti-phishing-key', orderId: 'itp-abc123', amount: '150.25', requestId: 'req_mb_1',
      entity: '12345', reference: '999888777', payment_datetime: '2026-09-07 15:30:00' }
  end

  it 'settles the charge and answers 200, which is all ifthenpay checks' do
    get url, params: valid_query

    expect(response).to have_http_status(:ok)
    expect(payment.reload.status).to eq('received')
    expect(connection.reload.finance_webhook_deliveries.count).to eq(1)
  end

  it 'accepts the same notification by POST' do
    post url, params: valid_query

    expect(response).to have_http_status(:ok)
    expect(payment.reload.status).to eq('received')
  end

  it 'rejects a callback carrying the wrong anti-phishing key' do
    get url, params: valid_query.merge(key: 'chave-errada')

    expect(response).to have_http_status(:unauthorized)
    expect(payment.reload.status).to eq('pending')
  end

  it 'rejects a callback with no anti-phishing key at all' do
    get url, params: valid_query.except(:key)

    expect(response).to have_http_status(:unauthorized)
    expect(payment.reload.status).to eq('pending')
  end

  it 'rejects an unknown connection without leaking whether it exists' do
    get "/webhooks/finance/ifthenpay/#{connection.id + 999}", params: valid_query

    expect(response).to have_http_status(:unauthorized)
  end

  it 'answers 422 for an unknown order so ifthenpay retries' do
    get url, params: valid_query.merge(orderId: 'nao-existe', requestId: 'nao-existe')

    expect(response).to have_http_status(:unprocessable_entity)
    expect(connection.reload.status).to eq('attention')
  end

  it 'stays at 200 and settles once when ifthenpay retries the same callback' do
    3.times { get url, params: valid_query }

    expect(response).to have_http_status(:ok)
    expect(payment.reload.finance_payment_events.where(event_type: 'PAYMENT_RECEIVED').count).to eq(1)
  end
end
