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
end
