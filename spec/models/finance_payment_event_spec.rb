require 'rails_helper'

RSpec.describe FinancePaymentEvent do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:connection) { FinanceProviderConnection.create!(account: account, provider: 'asaas', status: 'disconnected') }
  let(:payment) do
    FinancePayment.create!(
      account: account,
      contact: contact,
      finance_provider_connection: connection,
      amount_cents: 12_500
    )
  end

  it 'rejects duplicate provider event IDs for the same connection' do
    described_class.create!(
      account: account,
      finance_payment: payment,
      finance_provider_connection: connection,
      provider_event_id: 'evt_123',
      event_type: 'PAYMENT_RECEIVED',
      occurred_at: Time.current
    )

    duplicate = described_class.new(
      account: account,
      finance_payment: payment,
      finance_provider_connection: connection,
      provider_event_id: 'evt_123',
      event_type: 'PAYMENT_RECEIVED',
      occurred_at: Time.current
    )

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:provider_event_id]).to be_present
  end
end
