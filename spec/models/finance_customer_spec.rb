require 'rails_helper'

RSpec.describe FinanceCustomer do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:connection) { FinanceProviderConnection.create!(account: account, provider: 'asaas', status: 'disconnected') }

  it 'maps one provider customer to a contact for each connection' do
    customer = described_class.new(
      account: account,
      contact: contact,
      finance_provider_connection: connection,
      provider_customer_id: 'cus_123'
    )

    expect(customer).to be_valid
  end

  it 'prevents a duplicate customer mapping for the same contact and connection' do
    described_class.create!(
      account: account,
      contact: contact,
      finance_provider_connection: connection,
      provider_customer_id: 'cus_123'
    )

    duplicate = described_class.new(
      account: account,
      contact: contact,
      finance_provider_connection: connection,
      provider_customer_id: 'cus_456'
    )

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:contact_id]).to be_present
  end
end
