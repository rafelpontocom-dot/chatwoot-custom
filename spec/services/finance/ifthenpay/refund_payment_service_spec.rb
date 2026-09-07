require 'rails_helper'

RSpec.describe Finance::Ifthenpay::RefundPaymentService do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:connection) do
    account.create_finance_module_setting!(enabled: true, market: 'PT')
    FinanceProviderConnection.create!(
      account: account, provider: 'ifthenpay', environment: 'production',
      api_key: '1111-1111-1111-1111', webhook_token: 'anti-phishing-key', status: 'connected',
      settings: { 'mbway_key' => 'ITP-000222' }
    )
  end

  def build_payment(billing_type:, status:)
    FinancePayment.create!(
      account: account, contact: contact, finance_provider_connection: connection,
      amount_cents: 15_025, currency: 'EUR', billing_type: billing_type,
      external_reference: "itp-#{SecureRandom.hex(4)}", provider_payment_id: 'req_1', status: status
    )
  end

  it 'refunds a received MB WAY charge' do
    payment = build_payment(billing_type: 'mbway', status: 'received')
    stub_request(:post, Finance::Ifthenpay::Client::REFUND_URL)
      .to_return(status: 200, body: { Code: 1, Message: 'Successful refunded' }.to_json)

    described_class.new(payment: payment, actor: nil).perform

    expect(payment.reload.status).to eq('refunded')
    expect(WebMock).to(have_requested(:post, Finance::Ifthenpay::Client::REFUND_URL).with do |req|
      JSON.parse(req.body).values_at('backofficekey', 'requestId', 'amount') ==
        ['1111-1111-1111-1111', 'req_1', '150.25']
    end)
  end

  it 'reports insufficient balance in plain language' do
    payment = build_payment(billing_type: 'mbway', status: 'received')
    stub_request(:post, Finance::Ifthenpay::Client::REFUND_URL)
      .to_return(status: 200, body: { Code: -1, Message: 'no funds' }.to_json)

    expect { described_class.new(payment: payment, actor: nil).perform }
      .to raise_error(Finance::Ifthenpay::ApiError, /Insufficient balance/)
    expect(payment.reload.status).to eq('received')
  end

  it 'refuses to refund Multibanco, which the gateway cannot return' do
    payment = build_payment(billing_type: 'multibanco', status: 'received')

    expect { described_class.new(payment: payment, actor: nil).perform }
      .to raise_error(Finance::Ifthenpay::ApiError, /Multibanco and Payshop must be returned manually/)
  end

  it 'refuses to refund a charge that was never paid' do
    payment = build_payment(billing_type: 'mbway', status: 'pending')

    expect { described_class.new(payment: payment, actor: nil).perform }
      .to raise_error(Finance::Ifthenpay::ApiError, /not eligible/)
  end
end
