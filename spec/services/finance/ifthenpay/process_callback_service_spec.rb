require 'rails_helper'

RSpec.describe Finance::Ifthenpay::ProcessCallbackService do
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
  let(:payment) do
    FinancePayment.create!(
      account: account, contact: contact, finance_provider_connection: connection,
      amount_cents: 15_025, currency: 'EUR', billing_type: 'multibanco',
      external_reference: 'itp-abc123', provider_payment_id: 'req_mb_1', status: 'pending'
    )
  end

  it 'settles the payment named by orderId' do
    payment
    described_class.new(connection: connection, params: {
                          key: 'anti-phishing-key', orderId: 'itp-abc123', amount: '150.25',
                          requestId: 'req_mb_1', entity: '12345', reference: '999888777',
                          payment_datetime: '2026-09-07 15:30:00'
                        }).perform

    expect(payment.reload).to have_attributes(status: 'received')
    expect(payment.paid_at).to be_present
    expect(connection.reload.last_webhook_at).to be_present
  end

  it 'accepts the Payshop parameter names' do
    payment.update!(billing_type: 'payshop')
    described_class.new(connection: connection, params: {
                          anti_phishing_key: 'anti-phishing-key', order_id: 'itp-abc123', amount: '150.25'
                        }).perform

    expect(payment.reload.status).to eq('received')
  end

  it 'accepts the card parameter names' do
    payment.update!(billing_type: 'credit_card')
    described_class.new(connection: connection, params: {
                          key: 'anti-phishing-key', id: 'itp-abc123', amount: '150.25', payment_method: 'CCARD'
                        }).perform

    expect(payment.reload.status).to eq('received')
  end

  it 'is idempotent across ifthenpay retries' do
    payment
    params = { key: 'anti-phishing-key', orderId: 'itp-abc123', requestId: 'req_mb_1', amount: '150.25' }
    3.times { described_class.new(connection: connection, params: params).perform }

    expect(payment.finance_payment_events.where(event_type: 'PAYMENT_RECEIVED').count).to eq(1)
  end

  it 'ignores a settlement for an already refunded charge without losing the record' do
    payment.update!(status: 'refunded')
    event = described_class.new(connection: connection, params: {
                                  key: 'anti-phishing-key', orderId: 'itp-abc123', amount: '150.25'
                                }).perform

    expect(event.processing_status).to eq('ignored')
    expect(payment.reload.status).to eq('refunded')
  end

  it 'raises when no charge matches the order' do
    expect do
      described_class.new(connection: connection, params: { key: 'anti-phishing-key', orderId: 'desconhecido' }).perform
    end.to raise_error(ActiveRecord::RecordNotFound)
  end
end
