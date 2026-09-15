require 'rails_helper'

RSpec.describe 'Google Calendar OAuth callback', type: :request do
  let(:account) { create(:account) }
  let(:resource) { KanbanCalendarResource.create!(account: account, name: 'Dra. Ana', resource_type: 'user', timezone: 'America/Sao_Paulo') }

  before do
    allow(KanbanCalendar::GoogleCalendarOauthService).to receive(:resource_from_state!).with('state-1').and_return(resource)
  end

  it 'returns to the agenda of the account when Google connected' do
    connection = instance_double(KanbanCalendarGoogleConnection, account_id: account.id)
    service = instance_double(KanbanCalendar::GoogleCalendarOauthService, connect!: connection)
    allow(KanbanCalendar::GoogleCalendarOauthService).to receive(:new).with(resource: resource).and_return(service)

    get '/calendar/google/callback', params: { state: 'state-1', code: 'code-1' }

    expect(response).to redirect_to("/app/accounts/#{account.id}/calendar?google_calendar=connected")
  end

  it 'tells the agenda that the calendar permission was not granted' do
    service = instance_double(KanbanCalendar::GoogleCalendarOauthService)
    allow(service).to receive(:connect!).and_raise(KanbanCalendar::GoogleCalendarPermissionError)
    allow(KanbanCalendar::GoogleCalendarOauthService).to receive(:new).with(resource: resource).and_return(service)

    get '/calendar/google/callback', params: { state: 'state-1', code: 'code-1' }

    expect(response).to redirect_to("/app/accounts/#{account.id}/calendar?google_calendar=permission_denied")
  end

  it 'returns to the agenda with an error when the person cancels on Google' do
    get '/calendar/google/callback', params: { state: 'state-1', error: 'access_denied' }

    expect(response).to redirect_to("/app/accounts/#{account.id}/calendar?google_calendar=error")
  end
end
