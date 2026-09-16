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

  it 'says in the list which agendas are linked to Google Calendar' do
    KanbanCalendarGoogleConnection.create!(
      account: account, kanban_calendar_resource: resource, status: 'error', last_error: 'Google timeout',
      access_token: 'token', refresh_token: 'refresh', expires_at: 1.hour.from_now
    )
    KanbanCalendarResource.create!(account: account, name: 'Sala 1', resource_type: 'room', timezone: 'America/Sao_Paulo')

    get "/api/v1/accounts/#{account.id}/calendar/resources", headers: administrator.create_new_auth_token, as: :json

    expect(response.parsed_body.to_h { |item| [item['name'], item['google_calendar_status']] }).to eq(
      'Agenda da Dra. Ana' => 'error', 'Sala 1' => 'disconnected'
    )
  end

  # Agenda nova nasce com a semana comercial, para oferecer horário logo a seguir
  # a ser criada em vez de uma lista vazia sem explicação.
  it 'loads the default working hours and deactivates an agenda' do
    get "/api/v1/accounts/#{account.id}/calendar/resources/#{resource.id}/availability_rules",
        headers: administrator.create_new_auth_token,
        as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.map { |rule| [rule['weekday'], rule['starts_at_local'], rule['ends_at_local']] }).to eq(
      (1..5).map { |weekday| [weekday, '08:00', '18:00'] }
    )

    patch "/api/v1/accounts/#{account.id}/calendar/resources/#{resource.id}",
          headers: administrator.create_new_auth_token,
          params: { resource: { active: false } },
          as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('active' => false)
  end

  it 'saves the slot spacing chosen for the agenda' do
    patch "/api/v1/accounts/#{account.id}/calendar/resources/#{resource.id}",
          headers: administrator.create_new_auth_token,
          params: { resource: { slot_interval_minutes: 30 } },
          as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('slot_interval_minutes' => 30)
    expect(resource.reload.slot_interval_minutes).to eq(30)
  end
end
