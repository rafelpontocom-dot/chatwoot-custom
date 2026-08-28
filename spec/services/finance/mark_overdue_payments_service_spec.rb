require 'rails_helper'

RSpec.describe Finance::MarkOverduePaymentsService do
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
  let!(:overdue_payment) do
    FinancePayment.create!(
      account: account,
      contact: contact,
      finance_provider_connection: connection,
      amount_cents: 9_000,
      billing_type: 'other',
      currency: 'EUR',
      due_on: Date.new(2026, 8, 26),
      status: 'pending'
    )
  end

  it 'marks a manual charge past its due date as overdue and dispatches its event once' do
    dispatcher = instance_double(Finance::PaymentEventDispatcher, dispatch: nil)
    allow(Finance::PaymentEventDispatcher).to receive(:new).and_return(dispatcher)

    described_class.new(now: Time.zone.parse('2026-08-27 09:00:00')).perform!

    expect(overdue_payment.reload.status).to eq('overdue')
    expect(overdue_payment.finance_payment_events.last).to have_attributes(
      event_type: 'PAYMENT_OVERDUE',
      metadata: { 'source' => 'automatic_due_date' }
    )
    expect(Finance::PaymentEventDispatcher).to have_received(:new).once
  end

  it 'does not change a future charge or repeat an overdue event' do
    overdue_payment.update!(due_on: Date.new(2026, 8, 28))

    described_class.new(now: Time.zone.parse('2026-08-27 09:00:00')).perform!

    expect(overdue_payment.reload).to have_attributes(status: 'pending')
    expect(overdue_payment.finance_payment_events).to be_empty
  end
end
