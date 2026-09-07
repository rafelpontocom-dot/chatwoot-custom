require 'rails_helper'

RSpec.describe Finance::Ifthenpay::CancelPaymentService do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:connection) do
    account.create_finance_module_setting!(enabled: true, market: 'PT')
    FinanceProviderConnection.create!(
      account: account, provider: 'ifthenpay', environment: 'production',
      api_key: '1111-1111-1111-1111', webhook_token: 'anti-phishing-key', status: 'connected',
      settings: { 'mb_key' => 'ITP-000111' }
    )
  end
  let(:payment) do
    FinancePayment.create!(
      account: account, contact: contact, finance_provider_connection: connection,
      amount_cents: 15_025, currency: 'EUR', billing_type: 'multibanco',
      external_reference: 'itp-abc123', provider_payment_id: 'req_1', status: 'pending'
    )
  end

  before do
    allow(Finance::PaymentEventDispatcher)
      .to receive(:new).and_return(instance_double(Finance::PaymentEventDispatcher, dispatch: nil))
  end

  it 'cancels locally and records why no provider call was made' do
    described_class.new(payment: payment, actor: nil).perform

    expect(payment.reload.status).to eq('canceled')
    expect(payment.finance_payment_events.last.metadata['source']).to eq('ifthenpay_local_cancel')
  end

  it 'refuses to cancel a charge that was already settled' do
    payment.update!(status: 'received')

    expect { described_class.new(payment: payment, actor: nil).perform }
      .to raise_error(Finance::Ifthenpay::ApiError, /Only pending or overdue/)
  end
end
