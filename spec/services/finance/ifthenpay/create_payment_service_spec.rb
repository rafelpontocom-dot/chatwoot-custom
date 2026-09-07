require 'rails_helper'

RSpec.describe Finance::Ifthenpay::CreatePaymentService do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account, email: 'cliente@example.pt', phone_number: '+351912345678') }
  let(:connection) do
    account.finance_module_setting || account.create_finance_module_setting!(enabled: true, market: 'PT')
    FinanceProviderConnection.create!(
      account: account,
      provider: 'ifthenpay',
      environment: 'production',
      api_key: '1111-1111-1111-1111',
      webhook_token: 'anti-phishing-key',
      status: 'connected',
      settings: {
        'mb_key' => 'ITP-000111',
        'mbway_key' => 'ITP-000222',
        'payshop_key' => 'ITP-000333',
        'ccard_key' => 'ITP-000444'
      }
    )
  end

  before do
    dispatcher = instance_double(Finance::PaymentEventDispatcher, dispatch: nil)
    allow(Finance::PaymentEventDispatcher).to receive(:new).and_return(dispatcher)
  end

  def service(**overrides)
    described_class.new(
      connection: connection,
      contact: contact,
      amount_cents: 15_025,
      billing_type: 'multibanco',
      description: 'Implementação Comercial',
      **overrides
    )
  end

  it 'creates a Multibanco reference and keeps entity and reference readable' do
    stub_request(:post, Finance::Ifthenpay::Client::MULTIBANCO_URL)
      .to_return(status: 200, body: {
        Status: '0', Message: 'Success', Entity: '12345',
        Reference: '999 888 777', Amount: '150.25', RequestId: 'req_mb_1'
      }.to_json)

    payment = service.perform

    expect(payment).to have_attributes(
      status: 'pending', currency: 'EUR', billing_type: 'multibanco', provider_payment_id: 'req_mb_1'
    )
    expect(payment.provider_payload).to include(
      'ifthenpay_entity' => '12345',
      'ifthenpay_reference' => '999 888 777',
      'ifthenpay_method' => 'multibanco'
    )
  end

  it 'sends the amount with two decimals and an order id within the 25 character limit' do
    request = stub_request(:post, Finance::Ifthenpay::Client::MULTIBANCO_URL)
              .to_return(status: 200, body: { Status: '0', RequestId: 'req_mb_2' }.to_json)

    payment = service.perform

    expect(payment.external_reference.length).to be <= 25
    expect(request).to have_been_made
    expect(WebMock).to(have_requested(:post, Finance::Ifthenpay::Client::MULTIBANCO_URL)
      .with { |req| JSON.parse(req.body)['amount'] == '150.25' && JSON.parse(req.body)['mbKey'] == 'ITP-000111' })
  end

  it 'normalises a Portuguese mobile number for MB WAY' do
    stub_request(:post, Finance::Ifthenpay::Client::MBWAY_URL)
      .to_return(status: 200, body: { Status: '000', RequestId: 'req_mbway_1' }.to_json)

    service(billing_type: 'mbway').perform

    expect(WebMock).to(have_requested(:post, Finance::Ifthenpay::Client::MBWAY_URL)
      .with { |req| JSON.parse(req.body)['mobileNumber'] == '351#912345678' })
  end

  it 'refuses MB WAY when the contact has no valid Portuguese mobile' do
    contact.update!(phone_number: '+5511999999999')

    expect { service(billing_type: 'mbway').perform }
      .to raise_error(Finance::Ifthenpay::ApiError, /valid Portuguese mobile/)
    expect(FinancePayment.count).to eq(0)
  end

  it 'stores the hosted page returned for a card payment' do
    stub_request(:post, "#{Finance::Ifthenpay::Client::CREDIT_CARD_URL}ITP-000444")
      .to_return(status: 200, body: { Status: '0', RequestId: 'req_cc_1', PaymentUrl: 'https://pay.ifthenpay.com/x' }.to_json)

    payment = service(billing_type: 'credit_card').perform

    expect(payment.invoice_url).to eq('https://pay.ifthenpay.com/x')
  end

  it 'sends Payshop its own field names' do
    stub_request(:post, Finance::Ifthenpay::Client::PAYSHOP_URL)
      .to_return(status: 200, body: { Code: '0', RequestId: 'req_ps_1', Reference: '1234567890' }.to_json)

    service(billing_type: 'payshop', due_on: Date.new(2026, 9, 30)).perform

    expect(WebMock).to(have_requested(:post, Finance::Ifthenpay::Client::PAYSHOP_URL)
      .with do |req|
        body = JSON.parse(req.body)
        body['payshopkey'] == 'ITP-000333' && body['valor'] == '150.25' && body['validade'] == '20260930'
      end)
  end

  it 'rolls the charge back when ifthenpay rejects the request' do
    stub_request(:post, Finance::Ifthenpay::Client::MULTIBANCO_URL)
      .to_return(status: 200, body: { Status: '1', Message: 'Invalid key' }.to_json)

    expect { service.perform }.to raise_error(Finance::Ifthenpay::ApiError, /Invalid key/)
    expect(FinancePayment.count).to eq(0)
  end

  it 'refuses a billing type with no configured key' do
    connection.update!(settings: connection.settings.except('mbway_key'))

    expect { service(billing_type: 'mbway').perform }
      .to raise_error(Finance::Ifthenpay::ApiError, /No ifthenpay key configured/)
  end

  it 'refuses to charge through a connection that was never validated' do
    connection.update!(status: 'pending')

    expect { service.perform }.to raise_error(Finance::Ifthenpay::ApiError, /must be validated/)
  end
end
