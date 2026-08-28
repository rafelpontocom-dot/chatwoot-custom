require 'rails_helper'

RSpec.describe Finance::Asaas::CreatePaymentService do
  subject(:service) do
    described_class.new(
      connection: connection,
      contact: contact,
      amount_cents: 15_025,
      billing_type: 'pix',
      due_on: Date.new(2026, 8, 31),
      cpf_cnpj: '12345678909',
      description: 'Consulta'
    )
  end

  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account, email: 'pedro@example.com', phone_number: '+5511999999999') }
  let(:connection) do
    FinanceProviderConnection.create!(
      account: account,
      provider: 'asaas',
      environment: 'sandbox',
      api_key: 'asaas-test-key',
      status: 'connected'
    )
  end

  it 'creates an Asaas customer once and persists the returned charge' do
    dispatcher = instance_double(Finance::PaymentEventDispatcher, dispatch: nil)
    allow(Finance::PaymentEventDispatcher).to receive(:new).and_return(dispatcher)
    stub_request(:post, 'https://api-sandbox.asaas.com/v3/customers')
      .to_return(status: 200, body: { id: 'cus_001', name: contact.name }.to_json)
    stub_request(:post, 'https://api-sandbox.asaas.com/v3/payments')
      .to_return(status: 200, body: { id: 'pay_001', status: 'PENDING', invoiceUrl: 'https://pay.example/1' }.to_json)

    payment = service.perform

    expect(payment).to have_attributes(
      contact: contact,
      finance_provider_connection: connection,
      provider_customer_id: 'cus_001',
      provider_payment_id: 'pay_001',
      status: 'pending',
      invoice_url: 'https://pay.example/1'
    )
    expect(FinanceCustomer.find_by(contact: contact, finance_provider_connection: connection)).to have_attributes(provider_customer_id: 'cus_001')
    expect(payment.finance_payment_events.last).to have_attributes(
      event_type: 'PAYMENT_CREATED',
      metadata: { 'source' => 'asaas_create' }
    )
    expect(Finance::PaymentEventDispatcher).to have_received(:new).with(
      payment_event: payment.finance_payment_events.last
    )
  end

  it 'reuses the existing Asaas customer for a contact' do
    FinanceCustomer.create!(
      account: account,
      contact: contact,
      finance_provider_connection: connection,
      provider_customer_id: 'cus_existing'
    )
    stub_request(:post, 'https://api-sandbox.asaas.com/v3/customers').to_raise('customer must not be recreated')
    stub_request(:post, 'https://api-sandbox.asaas.com/v3/payments')
      .with(body: /"customer":"cus_existing"/)
      .to_return(status: 200, body: { id: 'pay_002', status: 'PENDING' }.to_json)

    payment = service.perform

    expect(payment.provider_customer_id).to eq('cus_existing')
  end

  it 'rejects charges from a connection that has not been validated' do
    connection.update!(status: 'pending')

    expect { service.perform }.to raise_error(
      Finance::Asaas::ApiError,
      'The Asaas connection must be validated before creating charges'
    )
  end

  it 'does not leave a local charge behind when Asaas rejects the creation' do
    stub_request(:post, 'https://api-sandbox.asaas.com/v3/customers')
      .to_return(status: 200, body: { id: 'cus_001', name: contact.name }.to_json)
    stub_request(:post, 'https://api-sandbox.asaas.com/v3/payments')
      .to_return(status: 422, body: { errors: [{ description: 'CPF inválido' }] }.to_json)

    expect { service.perform }.to raise_error(Finance::Asaas::ApiError, 'CPF inválido')

    expect(FinancePayment.where(finance_provider_connection: connection)).to be_empty
    expect(FinanceCustomer.find_by(contact: contact, finance_provider_connection: connection)).to have_attributes(
      provider_customer_id: 'cus_001'
    )
  end

  it 'reconciles a charge by external reference after an uncertain Asaas request' do
    dispatcher = instance_double(Finance::PaymentEventDispatcher, dispatch: nil)
    allow(Finance::PaymentEventDispatcher).to receive(:new).and_return(dispatcher)
    stub_request(:post, 'https://api-sandbox.asaas.com/v3/customers')
      .to_return(status: 200, body: { id: 'cus_001', name: contact.name }.to_json)
    stub_request(:post, 'https://api-sandbox.asaas.com/v3/payments')
      .to_raise(Net::ReadTimeout)
    stub_request(:get, %r{https://api-sandbox\.asaas\.com/v3/payments\?externalReference=})
      .to_return(
        status: 200,
        body: {
          data: [
            {
              id: 'pay_reconciled',
              status: 'PENDING',
              invoiceUrl: 'https://pay.example/reconciled'
            }
          ]
        }.to_json
      )

    payment = service.perform

    expect(payment).to have_attributes(
      provider_payment_id: 'pay_reconciled',
      status: 'pending',
      invoice_url: 'https://pay.example/reconciled'
    )
    expect(payment.finance_payment_events.where(event_type: 'PAYMENT_CREATED')).to have_attributes(count: 1)
  end

  it 'removes the local attempt when a timed out charge cannot be reconciled' do
    stub_request(:post, 'https://api-sandbox.asaas.com/v3/customers')
      .to_return(status: 200, body: { id: 'cus_001', name: contact.name }.to_json)
    stub_request(:post, 'https://api-sandbox.asaas.com/v3/payments')
      .to_raise(Net::ReadTimeout)
    stub_request(:get, %r{https://api-sandbox\.asaas\.com/v3/payments\?externalReference=})
      .to_return(status: 200, body: { data: [] }.to_json)

    expect { service.perform }.to raise_error(
      Finance::Asaas::ApiError,
      'Asaas payment could not be confirmed'
    )

    expect(FinancePayment.where(finance_provider_connection: connection)).to be_empty
  end
end
