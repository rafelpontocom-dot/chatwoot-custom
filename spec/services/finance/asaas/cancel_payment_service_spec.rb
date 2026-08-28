require 'rails_helper'

RSpec.describe Finance::Asaas::CancelPaymentService do
  subject(:service) { described_class.new(payment: payment, actor: administrator) }

  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:contact) { create(:contact, account: account) }
  let(:connection) do
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
      amount_cents: 15_000,
      billing_type: 'pix',
      due_on: Date.current + 2.days,
      provider_payment_id: 'pay_001',
      status: 'pending'
    )
  end

  it 'removes a pending Asaas charge and records the commercial audit event' do
    stub_request(:delete, 'https://api-sandbox.asaas.com/v3/payments/pay_001')
      .to_return(status: 200, body: { deleted: true, id: 'pay_001' }.to_json)
    dispatcher = instance_double(Finance::PaymentEventDispatcher, dispatch: nil)
    allow(Finance::PaymentEventDispatcher).to receive(:new).and_return(dispatcher)

    canceled_payment = service.perform

    expect(canceled_payment.reload.status).to eq('canceled')
    expect(canceled_payment.finance_payment_events.last).to have_attributes(
      event_type: 'PAYMENT_DELETED',
      actor: administrator,
      processing_status: 'processed'
    )
    expect(Finance::PaymentEventDispatcher).to have_received(:new).with(
      payment_event: canceled_payment.finance_payment_events.last
    )
  end

  it 'refuses to remove a payment already received' do
    payment.update!(status: 'received', paid_at: Time.current)

    expect { service.perform }.to raise_error(
      Finance::Asaas::ApiError,
      'Only pending or overdue charges can be canceled'
    )
  end
end
