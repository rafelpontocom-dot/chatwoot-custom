require 'rails_helper'

RSpec.describe Finance::Asaas::RetryWebhookDeliveryService do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:connection) do
    FinanceProviderConnection.create!(
      account: account,
      provider: 'asaas',
      environment: 'sandbox',
      api_key: 'asaas-test-key',
      webhook_token: 'a' * 32,
      status: 'attention'
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
  let(:raw_payload) do
    {
      id: 'evt_001',
      event: 'PAYMENT_RECEIVED',
      dateCreated: '2026-08-27 10:30:00',
      payment: { id: 'pay_001', status: 'RECEIVED' }
    }.to_json
  end
  let(:delivery) do
    FinanceWebhookDelivery.create!(
      account: account,
      finance_provider_connection: connection,
      provider_event_id: 'evt_001',
      payload_digest: Digest::SHA256.hexdigest(raw_payload),
      raw_payload: raw_payload,
      processing_status: 'failed',
      error_message: 'Webhook processing failed: ActiveRecord::RecordNotFound',
      received_at: Time.current
    )
  end

  it 'reprocesses a failed delivery without exposing its raw payload' do
    described_class.new(delivery: delivery).perform

    expect(payment.reload.status).to eq('received')
    expect(delivery.reload).to have_attributes(
      processing_status: 'processed',
      retry_count: 1,
      error_message: nil,
      processed_at: be_present
    )
    expect(connection.reload).to have_attributes(status: 'connected', last_error: nil)
  end

  it 'does not rerun a delivery that has already been processed' do
    delivery.update!(processing_status: 'processed')

    expect do
      described_class.new(delivery: delivery).perform
    end.to raise_error(ActiveRecord::RecordInvalid)
  end
end
