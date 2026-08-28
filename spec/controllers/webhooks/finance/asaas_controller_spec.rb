require 'rails_helper'

RSpec.describe 'Asaas finance webhook', type: :request do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:connection) do
    FinanceProviderConnection.create!(
      account: account,
      provider: 'asaas',
      environment: 'sandbox',
      api_key: 'asaas-test-key',
      webhook_token: 'a' * 32,
      status: 'connected'
    )
  end
  let!(:payment) do
    FinancePayment.create!(
      account: account,
      contact: contact,
      finance_provider_connection: connection,
      provider_payment_id: 'pay_001',
      external_reference: 'payment-42',
      amount_cents: 15_025,
      billing_type: 'pix',
      status: 'pending'
    )
  end
  let(:payload) do
    {
      id: 'evt_001',
      event: 'PAYMENT_RECEIVED',
      dateCreated: '2026-08-27 10:30:00',
      payment: { id: 'pay_001', status: 'RECEIVED' }
    }
  end

  it 'accepts an authenticated payment event' do
    post "/webhooks/finance/asaas/#{connection.id}",
         params: payload.to_json,
         headers: { 'CONTENT_TYPE' => 'application/json', 'asaas-access-token' => connection.webhook_token }

    expect(response).to have_http_status(:ok)
    expect(payment.reload.status).to eq('received')
  end

  it 'rejects a request with the wrong provider token' do
    post "/webhooks/finance/asaas/#{connection.id}",
         params: payload.to_json,
         headers: { 'CONTENT_TYPE' => 'application/json', 'asaas-access-token' => 'wrong-token' }

    expect(response).to have_http_status(:unauthorized)
  end

  it 'marks the connection for attention when an authenticated event cannot be matched' do
    invalid_payload = payload.deep_merge(payment: { id: 'pay_missing' })

    post "/webhooks/finance/asaas/#{connection.id}",
         params: invalid_payload.to_json,
         headers: { 'CONTENT_TYPE' => 'application/json', 'asaas-access-token' => connection.webhook_token }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(connection.reload).to have_attributes(
      status: 'attention',
      last_error: 'Webhook processing failed: ActiveRecord::RecordNotFound'
    )
    expect(FinanceWebhookDelivery.last).to have_attributes(
      processing_status: 'failed',
      provider_event_id: 'evt_001',
      error_message: 'Webhook processing failed: ActiveRecord::RecordNotFound'
    )
    expect(FinanceWebhookDelivery.last.public_payload).not_to have_key(:raw_payload)
  end

  it 'records a recoverable delivery when processing fails validation' do
    service = instance_double(Finance::Asaas::ProcessWebhookService)
    allow(Finance::Asaas::ProcessWebhookService).to receive(:new).and_return(service)
    allow(service).to receive(:perform).and_raise(ActiveRecord::RecordInvalid, payment)

    post "/webhooks/finance/asaas/#{connection.id}",
         params: payload.to_json,
         headers: { 'CONTENT_TYPE' => 'application/json', 'asaas-access-token' => connection.webhook_token }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(connection.reload.status).to eq('attention')
    expect(FinanceWebhookDelivery.last).to have_attributes(
      processing_status: 'failed',
      error_message: 'Webhook processing failed: ActiveRecord::RecordInvalid'
    )
  end
end
