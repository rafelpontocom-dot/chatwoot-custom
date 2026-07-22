require 'rails_helper'

RSpec.describe 'Kanban cadences API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:board) { create(:kanban_board, account: account) }

  def cadences_url
    "/api/v1/accounts/#{account.id}/kanban_boards/#{board.id}/cadences"
  end

  it 'allows administrators to create and list internal cadences' do
    post cadences_url,
         headers: administrator.create_new_auth_token,
         params: {
           cadence: {
             name: 'Proposta sem retorno',
             steps: [{ delay_hours: 24, action_type: 'Cobrar retorno', note: 'Confirmar recebimento' }]
           }
         },
         as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to include('name' => 'Proposta sem retorno')

    get cadences_url, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.first['steps'].first['action_type']).to eq('Cobrar retorno')
  end

  it 'rejects customer message steps' do
    post cadences_url,
         headers: administrator.create_new_auth_token,
         params: { cadence: { name: 'Invalida', steps: [{ delay_hours: 0, action_type: 'send_message' }] } },
         as: :json

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'does not allow agents to change cadence configuration' do
    post cadences_url,
         headers: agent.create_new_auth_token,
         params: { cadence: { name: 'Regra', steps: [{ delay_hours: 0, action_type: 'Follow-up' }] } },
         as: :json

    expect(response).to have_http_status(:unauthorized)
  end
end
