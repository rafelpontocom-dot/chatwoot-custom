require 'rails_helper'

RSpec.describe 'Raevo AI finance commands API', type: :request do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, contact: contact) }
  let(:board) { create(:kanban_board, account: account) }
  let(:stage) { create(:kanban_stage, account: account, kanban_board: board, name: 'Proposal') }
  let(:card) do
    create(:kanban_card, :conversation_origin, account: account, kanban_board: board, kanban_stage: stage, conversation: conversation)
  end
  let(:connection) do
    FinanceModuleSetting.create!(account: account, market: 'PT', enabled: true)
    FinanceProviderConnection.create!(account: account, provider: 'manual', environment: 'production', status: 'connected')
  end
  let(:token) { 'a' * 64 }
  let(:integration) do
    RaevoAiIntegration.create!(
      account: account,
      clinic_id: 'clinic-demo',
      enabled: true,
      settings: {
        'command_token_digest' => Digest::SHA256.hexdigest(token),
        'crm' => { 'boards' => { 'acquisition' => { 'board_id' => board.id } } },
        'finance' => {
          'charges' => {
            'consultation_fee' => {
              'board_key' => 'acquisition',
              'provider_connection_id' => connection.id,
              'amount_cents' => 9000,
              'billing_type' => 'other',
              'currency' => 'EUR',
              'due_in_days' => 1,
              'description' => 'Published consultation fee'
            }
          }
        }
      }
    )
  end
  let(:headers) { { 'X-Raevo-Clinic-Id' => integration.clinic_id, 'X-Raevo-Command-Token' => token } }

  it 'creates only the catalog-published charge for the trusted conversation opportunity' do
    card
    post '/public/api/v1/raevo_ai/finance/charges', params: {
      action_id: 'turn-100:charge:consultation',
      conversation_id: conversation.display_id,
      board_key: 'acquisition',
      charge_key: 'consultation_fee',
      amount_cents: 1,
      finance_provider_connection_id: 999_999
    }, headers: headers, as: :json

    expect(response).to have_http_status(:ok), response.body
    payment = FinancePayment.last
    expect(payment).to have_attributes(
      account: account,
      contact: contact,
      kanban_card: card,
      finance_provider_connection: connection,
      amount_cents: 9000,
      currency: 'EUR',
      status: 'pending'
    )
    expect(response.parsed_body).to include(
      'action_id' => 'turn-100:charge:consultation',
      'status' => 'applied'
    )
    expect(response.parsed_body.dig('receipts', 'payment', 'payment_id')).to eq(payment.id)
  end

  it 'replays the command receipt without creating another charge' do
    card
    params = {
      action_id: 'turn-100:charge:consultation',
      conversation_id: conversation.display_id,
      board_key: 'acquisition',
      charge_key: 'consultation_fee'
    }

    post '/public/api/v1/raevo_ai/finance/charges', params: params, headers: headers, as: :json

    expect do
      post '/public/api/v1/raevo_ai/finance/charges', params: params, headers: headers, as: :json
    end.not_to change(FinancePayment, :count)

    expect(response).to have_http_status(:ok)
  end

  it 'rejects a charge key that the tenant did not publish' do
    post '/public/api/v1/raevo_ai/finance/charges', params: {
      action_id: 'turn-100:charge:unpublished',
      conversation_id: conversation.display_id,
      board_key: 'acquisition',
      charge_key: 'unpublished'
    }, headers: headers, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body).to eq('error' => 'invalid_catalog')
    expect(FinancePayment.all).to be_empty
  end

  it 'rejects finance commands while the account finance module is disabled' do
    connection
    card
    FinanceModuleSetting.find_by!(account: account).update!(enabled: false)

    post '/public/api/v1/raevo_ai/finance/charges', params: {
      action_id: 'turn-100:charge:finance-disabled',
      conversation_id: conversation.display_id,
      board_key: 'acquisition',
      charge_key: 'consultation_fee'
    }, headers: headers, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body).to eq('error' => 'invalid_catalog')
    expect(FinancePayment.all).to be_empty
  end

  context 'with an Asaas charge' do
    let(:connection) do
      FinanceModuleSetting.create!(account: account, market: 'BR', enabled: true)
      FinanceProviderConnection.create!(
        account: account, provider: 'asaas', environment: 'sandbox', status: 'connected', api_key: 'sandbox-key'
      )
    end

    before do
      integration.settings['finance']['charges']['consultation_fee'].merge!(
        'billing_type' => 'undefined', 'currency' => 'BRL', 'tax_id_source' => 'command'
      )
      integration.save!
    end

    it 'uses a validated inline tax id without persisting its plaintext in the command receipt' do
      card
      payment = instance_double(FinancePayment, id: 42, status: 'pending', invoice_url: 'https://sandbox.asaas.test/pay/42')
      service = instance_double(Finance::Asaas::CreatePaymentService, perform: payment)
      expect(Finance::Asaas::CreatePaymentService).to receive(:new)
        .with(hash_including(cpf_cnpj: '12345678901'))
        .and_return(service)

      post '/public/api/v1/raevo_ai/finance/charges', params: {
        action_id: 'turn-101:charge:consultation',
        conversation_id: conversation.display_id,
        board_key: 'acquisition',
        charge_key: 'consultation_fee',
        tax_id: '123.456.789-01'
      }, headers: headers, as: :json

      expect(response).to have_http_status(:ok), response.body
      command = integration.raevo_ai_commands.find_by!(action_id: 'turn-101:charge:consultation')
      expect(command.result.to_json).not_to include('12345678901', '123.456.789-01')
      expect(command.payload_digest).to be_present
    end
  end
end
