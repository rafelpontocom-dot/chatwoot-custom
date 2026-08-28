require 'rails_helper'

RSpec.describe Finance::PaymentsSummary do
  let(:account) { create(:account) }
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

  it 'keeps expected, received and overdue totals separated by currency' do
    create_payment(status: 'pending', amount_cents: 10_000, currency: 'BRL')
    create_payment(status: 'confirmed', amount_cents: 20_000, currency: 'BRL')
    create_payment(status: 'received', amount_cents: 30_000, currency: 'BRL')
    create_payment(status: 'overdue', amount_cents: 40_000, currency: 'EUR')

    summary = described_class.new(scope: account.finance_payments).call

    expect(summary).to eq(
      open: [{ currency: 'BRL', count: 2, amount_cents: 30_000 }],
      received: [{ currency: 'BRL', count: 1, amount_cents: 30_000 }],
      overdue: [{ currency: 'EUR', count: 1, amount_cents: 40_000 }]
    )
  end

  private

  def create_payment(status:, amount_cents:, currency:)
    FinancePayment.create!(
      account: account,
      contact: contact,
      finance_provider_connection: connection,
      amount_cents: amount_cents,
      billing_type: 'pix',
      currency: currency,
      status: status
    )
  end
end
