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

  it 'imports the Google busy times now and reports the time of the import' do
    connection = KanbanCalendarGoogleConnection.create!(
      account: account, kanban_calendar_resource: resource, access_token: 'access-token',
      refresh_token: 'refresh-token', expires_at: 1.hour.from_now, status: 'error', last_error: 'Google timeout'
    )
    import = instance_double(KanbanCalendar::GoogleCalendarImportService)
    allow(import).to receive(:perform!) { connection.update!(last_imported_at: Time.current) }
    allow(KanbanCalendar::GoogleCalendarImportService).to receive(:new).with(connection: connection).and_return(import)
    allow(KanbanCalendar::BackfillGoogleCalendarConnectionJob).to receive(:perform_later)

    post "/api/v1/accounts/#{account.id}/calendar/resources/#{resource.id}/google_calendar_connection/sync",
         headers: administrator.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('connected' => true, 'last_error' => nil)
    expect(response.parsed_body['last_imported_at']).to be_present
    expect(KanbanCalendar::BackfillGoogleCalendarConnectionJob).to have_received(:perform_later).with(connection.id)
  end

  it 'answers with the Google message when the import fails, so the settings can show why' do
    connection = KanbanCalendarGoogleConnection.create!(
      account: account, kanban_calendar_resource: resource, access_token: 'access-token',
      refresh_token: 'refresh-token', expires_at: 1.hour.from_now, status: 'connected'
    )
    import = instance_double(KanbanCalendar::GoogleCalendarImportService)
    allow(import).to receive(:perform!) do
      connection.update!(status: 'error', last_error: 'Request had insufficient authentication scopes.')
      raise KanbanCalendar::GoogleCalendarApiError, 'Request had insufficient authentication scopes.'
    end
    allow(KanbanCalendar::GoogleCalendarImportService).to receive(:new).and_return(import)

    post "/api/v1/accounts/#{account.id}/calendar/resources/#{resource.id}/google_calendar_connection/sync",
         headers: administrator.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body).to include('status' => 'error', 'last_error' => 'Request had insufficient authentication scopes.')
  end

  it 'stops blocking the agenda with Google busy times after disconnecting' do
    KanbanCalendarExternalBusyBlock.create!(
      account: account, kanban_calendar_resource: resource, provider: 'google_calendar',
      external_event_id: 'dentista', starts_at: 1.day.from_now, ends_at: 1.day.from_now + 1.hour
    )

    delete "/api/v1/accounts/#{account.id}/calendar/resources/#{resource.id}/google_calendar_connection",
           headers: administrator.create_new_auth_token,
           as: :json

    expect(resource.kanban_calendar_external_busy_blocks).to be_empty
  end
end
