require 'rails_helper'

RSpec.describe Finance::Asaas::Client do
  subject(:client) { described_class.new(connection: connection) }

  let(:account) { create(:account) }
  let(:connection) do
    FinanceProviderConnection.create!(
      account: account,
      provider: 'asaas',
      environment: 'sandbox',
      api_key: 'asaas-test-key',
      status: 'connected'
    )
  end

  describe '#create_customer' do
    it 'sends the customer payload to the selected Asaas environment' do
      stub_request(:post, 'https://api-sandbox.asaas.com/v3/customers')
        .with(
          headers: { 'access_token' => 'asaas-test-key', 'Content-Type' => 'application/json' },
          body: {
            name: 'Pedro Raevo',
            cpfCnpj: '12345678909',
            email: 'pedro@example.com',
            mobilePhone: '+5511999999999',
            externalReference: 'contact-42'
          }.to_json
        ).to_return(status: 200, body: { id: 'cus_001', name: 'Pedro Raevo' }.to_json)

      result = client.create_customer(
        name: 'Pedro Raevo',
        cpf_cnpj: '12345678909',
        email: 'pedro@example.com',
        mobile_phone: '+5511999999999',
        external_reference: 'contact-42'
      )

      expect(result).to include('id' => 'cus_001')
    end
  end

  describe '#account' do
    it 'reads the connected Asaas account without exposing its credential' do
      stub_request(:get, 'https://api-sandbox.asaas.com/v3/myAccount')
        .with(headers: { 'access_token' => 'asaas-test-key' })
        .to_return(status: 200, body: { id: 'account_001', name: 'Clínica RAEVO' }.to_json)

      expect(client.account).to include('id' => 'account_001')
    end
  end

  describe '#create_payment' do
    it 'sends the charge with its immutable external reference' do
      stub_request(:post, 'https://api-sandbox.asaas.com/v3/payments')
        .with(
          headers: { 'access_token' => 'asaas-test-key', 'Content-Type' => 'application/json' },
          body: {
            customer: 'cus_001',
            billingType: 'PIX',
            value: 150.25,
            dueDate: '2026-08-31',
            description: 'Consulta',
            externalReference: 'payment-42'
          }.to_json
        ).to_return(status: 200, body: { id: 'pay_001', status: 'PENDING' }.to_json)

      result = client.create_payment(
        customer_id: 'cus_001',
        payload: {
          billing_type: 'PIX',
          value: 150.25,
          due_date: Date.new(2026, 8, 31),
          description: 'Consulta',
          external_reference: 'payment-42'
        }
      )

      expect(result).to include('id' => 'pay_001', 'status' => 'PENDING')
    end
  end

  describe '#create_customer when Asaas rejects the customer' do
    it 'raises a provider error with the Asaas message' do
      stub_request(:post, 'https://api-sandbox.asaas.com/v3/customers')
        .to_return(status: 422, body: { errors: [{ description: 'CPF inválido' }] }.to_json)

      expect do
        client.create_customer(name: 'Pedro Raevo', cpf_cnpj: 'invalid', external_reference: 'contact-42')
      end.to raise_error(Finance::Asaas::ApiError, 'CPF inválido')
    end
  end

  describe '#refund_payment' do
    it 'requests the full refund with an optional reason' do
      stub_request(:post, 'https://api-sandbox.asaas.com/v3/payments/pay_001/refund')
        .with(
          headers: { 'access_token' => 'asaas-test-key', 'Content-Type' => 'application/json' },
          body: { description: 'Cobrança duplicada' }.to_json
        ).to_return(status: 200, body: { id: 'pay_001', status: 'RECEIVED' }.to_json)

      expect(client.refund_payment('pay_001', description: 'Cobrança duplicada')).to include('id' => 'pay_001')
    end
  end
end
