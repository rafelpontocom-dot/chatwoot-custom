require 'rails_helper'

RSpec.describe Finance::Manual::CancelPaymentService do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:actor) { create(:user, account: account, role: :administrator) }
  let(:setting) { FinanceModuleSetting.create!(account: account, market: 'PT', enabled: true) }
  let(:dispatcher) { instance_double(Finance::PaymentEventDispatcher, dispatch: nil) }
  let(:connection) do
    setting
    FinanceProviderConnection.create!(
      account: account,
      provider: 'manual',
      environment: 'production',
      status: 'connected'
    )
  end
  let(:payment) do
    FinancePayment.create!(
      account: account,
      contact: contact,
      finance_provider_connection: connection,
      amount_cents: 9_000,
      billing_type: 'other',
      currency: 'EUR',
      status: 'pending'
    )
  end

  it 'cancels a pending external charge and records an audit event' do
    allow(Finance::PaymentEventDispatcher).to receive(:new).and_return(dispatcher)

    described_class.new(payment: payment, actor: actor).perform

    expect(payment.reload.status).to eq('canceled')
    expect(payment.finance_payment_events.last).to have_attributes(
      event_type: 'PAYMENT_DELETED',
      actor: actor,
      processing_status: 'processed'
    )
  end

  it 'does not cancel a received external charge' do
    payment.update!(status: 'received')

    expect { described_class.new(payment: payment, actor: actor).perform }
      .to raise_error(ActiveRecord::RecordInvalid)
  end
end
