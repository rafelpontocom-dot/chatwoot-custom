require 'rails_helper'

RSpec.describe Finance::Asaas::RefundPaymentService do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:actor) { create(:user, account: account, role: :administrator) }
  let(:setting) { FinanceModuleSetting.create!(account: account, market: 'BR', enabled: true) }
  let(:connection) do
    setting
    FinanceProviderConnection.create!(
      account: account,
      provider: 'asaas',
      environment: 'sandbox',
      api_key: 'asaas-test-key',
      status: 'connected'
    )
  end
  let(:payment) do
    FinancePayment.create!(
      account: account,
      contact: contact,
      finance_provider_connection: connection,
      provider_payment_id: 'pay_001',
      amount_cents: 15_025,
      billing_type: 'pix',
      status: 'received'
    )
  end

  it 'requests a full Asaas refund once and keeps the payment status for the webhook' do
    stub_request(:post, 'https://api-sandbox.asaas.com/v3/payments/pay_001/refund')
      .with(body: { description: 'Cobrança duplicada' }.to_json)
      .to_return(status: 200, body: { id: 'pay_001', status: 'RECEIVED' }.to_json)

    described_class.new(payment: payment, actor: actor, description: 'Cobrança duplicada').perform

    expect(payment.reload.status).to eq('received')
    expect(payment.finance_payment_events.last).to have_attributes(
      event_type: 'PAYMENT_REFUND_REQUESTED',
      actor: actor,
      metadata: include('source' => 'asaas_refund_request')
    )
  end

  it 'does not request a second refund for the same payment' do
    payment.finance_payment_events.create!(
      account: account,
      finance_provider_connection: connection,
      event_type: 'PAYMENT_REFUND_REQUESTED',
      occurred_at: Time.current,
      metadata: { source: 'asaas_refund_request' }
    )

    expect { described_class.new(payment: payment, actor: actor).perform }
      .to raise_error(ActiveRecord::RecordInvalid)
  end

  it 'does not use the generic refund endpoint for boleto' do
    payment.update!(billing_type: 'boleto')

    expect { described_class.new(payment: payment, actor: actor).perform }
      .to raise_error(Finance::Asaas::ApiError)
  end
end
