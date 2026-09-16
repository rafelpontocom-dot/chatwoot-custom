require 'rails_helper'

RSpec.describe 'Calendar Feegow connection API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:path) { "/api/v1/accounts/#{account.id}/calendar/feegow_connection" }

  it 'says the clinic is not connected before any token is saved' do
    get path, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('connected' => false, 'status' => 'disconnected')
  end

  # O token do Feegow vence a cada 90 dias. Quem não informa a validade fica com
  # a que o Feegow pratica, para o aviso existir desde o primeiro dia.
  it 'saves the token and defaults its expiry to ninety days' do
    freeze_time do
      put path, headers: administrator.create_new_auth_token,
                params: { feegow_connection: { api_token: 'token-da-clinica' } }, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('connected' => true, 'status' => 'connected')
      expect(Time.zone.parse(response.parsed_body['token_expires_at']).to_i).to eq(90.days.from_now.to_i)
      expect(response.parsed_body['token_expires_in_days']).to eq(90)
    end
  end

  it 'keeps the expiry date the clinic informed' do
    put path, headers: administrator.create_new_auth_token,
              params: { feegow_connection: { api_token: 'token-da-clinica', token_expires_at: '2026-12-01T00:00:00-03:00' } },
              as: :json

    expect(Time.zone.parse(response.parsed_body['token_expires_at']).to_date).to eq(Date.new(2026, 12, 1))
  end

  it 'never sends the token back to the browser' do
    put path, headers: administrator.create_new_auth_token,
              params: { feegow_connection: { api_token: 'token-da-clinica' } }, as: :json

    expect(response.parsed_body).not_to have_key('api_token')
    expect(response.body).not_to include('token-da-clinica')
  end

  it 'imports now and reports when Feegow was last read' do
    connection = KanbanCalendarFeegowConnection.create!(account: account, api_token: 'token', status: 'connected')
    import = instance_double(KanbanCalendar::FeegowImportService)
    allow(import).to receive(:perform!) { connection.update!(last_imported_at: Time.current) }
    allow(KanbanCalendar::FeegowImportService).to receive(:new).and_return(import)

    post "#{path}/sync", headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['last_imported_at']).to be_present
  end

  it 'answers with the Feegow reason when the import fails' do
    connection = KanbanCalendarFeegowConnection.create!(account: account, api_token: 'token', status: 'connected')
    import = instance_double(KanbanCalendar::FeegowImportService)
    allow(import).to receive(:perform!) do
      connection.update!(status: 'error', last_error: 'Token inválido')
      raise KanbanCalendar::FeegowApiError, 'Token inválido'
    end
    allow(KanbanCalendar::FeegowImportService).to receive(:new).and_return(import)

    post "#{path}/sync", headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body).to include('status' => 'error', 'last_error' => 'Token inválido')
  end

  it 'stops blocking the agenda after disconnecting' do
    connection = KanbanCalendarFeegowConnection.create!(account: account, api_token: 'token', status: 'connected')
    resource = KanbanCalendarResource.create!(account: account, name: 'Dra. Anna', resource_type: 'user', timezone: 'America/Sao_Paulo')
    KanbanCalendarExternalBusyBlock.create!(
      account: account, kanban_calendar_resource: resource, provider: 'feegow',
      external_event_id: '500', starts_at: 1.day.from_now, ends_at: 1.day.from_now + 30.minutes
    )

    delete path, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:no_content)
    expect(connection.reload).to have_attributes(status: 'disconnected', api_token: nil)
    expect(resource.kanban_calendar_external_busy_blocks).to be_empty
  end

  it 'lists the Feegow professionals so each agenda can be mapped' do
    KanbanCalendarFeegowConnection.create!(account: account, api_token: 'token', status: 'connected')
    client = instance_double(KanbanCalendar::FeegowClient, professionals: [{ 'profissional_id' => 9, 'nome' => 'Dra. Anna' }])
    allow(KanbanCalendar::FeegowClient).to receive(:new).and_return(client)

    get "#{path}/professionals", headers: administrator.create_new_auth_token, as: :json

    expect(response.parsed_body).to eq([{ 'id' => '9', 'name' => 'Dra. Anna' }])
  end

  it 'keeps the token out of an agent\'s hands' do
    put path, headers: agent.create_new_auth_token,
              params: { feegow_connection: { api_token: 'token-da-clinica' } }, as: :json

    expect(response).to have_http_status(:unauthorized)
  end
end
