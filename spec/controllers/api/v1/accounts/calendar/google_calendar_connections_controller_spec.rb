require 'rails_helper'

RSpec.describe 'Calendar Google connections API', type: :request do
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

  it 'shows an agenda as disconnected before Google OAuth is configured' do
    get "/api/v1/accounts/#{account.id}/calendar/resources/#{resource.id}/google_calendar_connection",
        headers: administrator.create_new_auth_token,
        as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('connected' => false, 'status' => 'disconnected')
  end

  it 'returns the Google authorization URL for an administrator' do
    service = instance_double(KanbanCalendar::GoogleCalendarOauthService, authorization_url: 'https://accounts.google.com/o/oauth2/auth')
    allow(KanbanCalendar::GoogleCalendarOauthService).to receive(:new).with(resource: resource).and_return(service)

    post "/api/v1/accounts/#{account.id}/calendar/resources/#{resource.id}/google_calendar_connection/authorization_url",
         headers: administrator.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to eq('url' => 'https://accounts.google.com/o/oauth2/auth')
  end

  it 'disconnects without deleting the persistent agenda mapping' do
    connection = KanbanCalendarGoogleConnection.create!(
      account: account,
      kanban_calendar_resource: resource,
      access_token: 'access-token',
      refresh_token: 'refresh-token',
      expires_at: 1.hour.from_now,
      status: 'connected'
    )

    delete "/api/v1/accounts/#{account.id}/calendar/resources/#{resource.id}/google_calendar_connection",
           headers: administrator.create_new_auth_token,
           as: :json

    expect(response).to have_http_status(:no_content)
    expect(connection.reload).to have_attributes(
      status: 'disconnected',
      access_token: nil,
      refresh_token: nil
    )
  end

  it 'reprocesses future exports after a recoverable Google failure' do
    connection = KanbanCalendarGoogleConnection.create!(
      account: account,
      kanban_calendar_resource: resource,
      access_token: 'access-token',
      refresh_token: 'refresh-token',
      expires_at: 1.hour.from_now,
      status: 'error',
      last_error: 'Google timeout'
    )
    allow(KanbanCalendar::BackfillGoogleCalendarConnectionJob).to receive(:perform_later)

    post "/api/v1/accounts/#{account.id}/calendar/resources/#{resource.id}/google_calendar_connection/retry",
         headers: administrator.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:success)
    expect(connection.reload).to have_attributes(status: 'connected', last_error: nil)
    expect(KanbanCalendar::BackfillGoogleCalendarConnectionJob).to have_received(:perform_later).with(connection.id)
  end

  it 'does not retry an agenda that is not in an error state' do
    KanbanCalendarGoogleConnection.create!(
      account: account,
      kanban_calendar_resource: resource,
      access_token: 'access-token',
      refresh_token: 'refresh-token',
      expires_at: 1.hour.from_now,
      status: 'connected'
    )
    allow(KanbanCalendar::BackfillGoogleCalendarConnectionJob).to receive(:perform_later)

    post "/api/v1/accounts/#{account.id}/calendar/resources/#{resource.id}/google_calendar_connection/retry",
         headers: administrator.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(KanbanCalendar::BackfillGoogleCalendarConnectionJob).not_to have_received(:perform_later)
  end
end
