require 'rails_helper'

RSpec.describe 'Kanban automation connections API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:board) { create(:kanban_board, account: account) }

  def connections_url
    "/api/v1/accounts/#{account.id}/kanban_boards/#{board.id}/automation_connections"
  end

  it 'creates a connection, returns the secret once, and does not expose it when listed' do
    post connections_url,
         headers: administrator.create_new_auth_token,
         params: {
           automation_connection: {
             name: 'n8n produção',
             webhook_url: 'https://automacao.example.test/webhook/lead'
           }
         },
         as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to include('name' => 'n8n produção', 'secret' => a_kind_of(String))
    expect(response.parsed_body['inbound_webhook_url']).to end_with("/webhooks/kanban/#{KanbanAutomationConnection.last.inbound_token}")

    get connections_url, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.first).to include('name' => 'n8n produção', 'secret_present' => true)
    expect(response.parsed_body.first).not_to have_key('secret')
  end
end
