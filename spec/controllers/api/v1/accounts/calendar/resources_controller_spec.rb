require 'rails_helper'

RSpec.describe 'Calendar resources API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:resource) do
    KanbanCalendarResource.create!(
      account: account,
      name: 'Agenda da Dra. Ana',
      resource_type: 'generic',
      timezone: 'America/Sao_Paulo'
    )
  end

  it 'loads availability and deactivates an agenda' do
    get "/api/v1/accounts/#{account.id}/calendar/resources/#{resource.id}/availability_rules",
        headers: administrator.create_new_auth_token,
        as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to eq([])

    patch "/api/v1/accounts/#{account.id}/calendar/resources/#{resource.id}",
          headers: administrator.create_new_auth_token,
          params: { resource: { active: false } },
          as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('active' => false)
  end
end
