require 'rails_helper'

RSpec.describe Finance::Manual::CreatePaymentService do
  subject(:service) do
    described_class.new(
      connection: connection,
      contact: contact,
      amount_cents: 9_000,
      billing_type: 'other',
      due_on: Date.new(2026, 9, 4),
      description: 'Consulta registada fora do CRM',
      currency: 'EUR'
    )
  end

  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:setting) { FinanceModuleSetting.create!(account: account, market: 'PT', enabled: true) }
  let(:connection) do
    setting
    FinanceProviderConnection.create!(
      account: account,
      provider: 'manual',
      environment: 'production',
      status: 'connected'
    )
  end

  it 'records an external charge without a provider request' do
    dispatcher = instance_double(Finance::PaymentEventDispatcher, dispatch: nil)
    allow(Finance::PaymentEventDispatcher).to receive(:new).and_return(dispatcher)

    payment = service.perform

    expect(payment).to have_attributes(
      account: account,
      contact: contact,
      finance_provider_connection: connection,
      amount_cents: 9_000,
      billing_type: 'other',
      currency: 'EUR',
      status: 'pending',
      provider_payment_id: nil,
      invoice_url: nil
    )
    expect(payment.finance_payment_events.last).to have_attributes(
      event_type: 'PAYMENT_CREATED',
      metadata: { 'source' => 'manual_create' }
    )
    expect(Finance::PaymentEventDispatcher).to have_received(:new).with(
      payment_event: payment.finance_payment_events.last
    )
  end
end
