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

    expect(summary).to include(
      open: [{ currency: 'BRL', count: 2, amount_cents: 30_000 }],
      received: [{ currency: 'BRL', count: 1, amount_cents: 30_000 }],
      overdue: [{ currency: 'EUR', count: 1, amount_cents: 40_000 }]
    )
  end

  it 'separates what was received this month from the month before, by paid_at' do
    travel_to Time.zone.parse('2026-09-18 10:00') do
      create_payment(status: 'received', amount_cents: 30_000, currency: 'BRL',
                     paid_at: Time.zone.parse('2026-09-04 09:00'))
      create_payment(status: 'received', amount_cents: 20_000, currency: 'BRL',
                     paid_at: Time.zone.parse('2026-08-27 09:00'))

      summary = described_class.new(scope: account.finance_payments).call

      expect(summary[:month]).to eq(
        received: [{ currency: 'BRL', count: 1, amount_cents: 30_000 }],
        received_previous: [{ currency: 'BRL', count: 1, amount_cents: 20_000 }]
      )
    end
  end

  it 'reports the due date of the oldest overdue charge' do
    create_payment(status: 'overdue', amount_cents: 10_000, currency: 'BRL',
                   due_on: Date.new(2026, 9, 2))
    create_payment(status: 'overdue', amount_cents: 20_000, currency: 'BRL',
                   due_on: Date.new(2026, 9, 11))

    summary = described_class.new(scope: account.finance_payments).call

    expect(summary[:overdue_oldest_due_on]).to eq(Date.new(2026, 9, 2))
  end

  private

  def create_payment(status:, amount_cents:, currency:, paid_at: nil, due_on: nil)
    FinancePayment.create!(
      account: account,
      contact: contact,
      finance_provider_connection: connection,
      amount_cents: amount_cents,
      billing_type: 'pix',
      currency: currency,
      status: status,
      paid_at: paid_at,
      due_on: due_on
    )
  end
end
