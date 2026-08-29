require 'rails_helper'

RSpec.describe FinancePayment do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:connection) { FinanceProviderConnection.create!(account: account, provider: 'asaas', status: 'disconnected') }

  it 'creates a draft charge with an immutable internal reference' do
    payment = described_class.new(
      account: account,
      contact: contact,
      finance_provider_connection: connection,
      amount_cents: 12_500,
      billing_type: 'pix',
      due_on: Date.current
    )

    expect(payment).to be_valid
    expect(payment.external_reference).to be_present
    expect(payment.status).to eq('draft')
  end

  it 'requires a positive amount' do
    payment = described_class.new(
      account: account,
      contact: contact,
      finance_provider_connection: connection,
      amount_cents: 0
    )

    expect(payment).not_to be_valid
    expect(payment.errors[:amount_cents]).to be_present
  end

  it 'requires at least R$ 5,00 for an Asaas charge' do
    payment = described_class.new(
      account: account,
      contact: contact,
      finance_provider_connection: connection,
      amount_cents: 499,
      billing_type: 'pix'
    )

    expect(payment).not_to be_valid
    expect(payment.errors[:amount_cents]).to include('must be at least 500 cents for Asaas charges')
  end
end
