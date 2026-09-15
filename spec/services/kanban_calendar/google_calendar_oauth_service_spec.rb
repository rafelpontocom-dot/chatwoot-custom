require 'rails_helper'

RSpec.describe KanbanCalendar::GoogleCalendarOauthService do
  let(:account) { create(:account) }
  let(:resource) do
    KanbanCalendarResource.create!(
      account: account,
      name: 'Agenda da Dra. Ana',
      resource_type: 'generic',
      timezone: 'America/Sao_Paulo'
    )
  end

  # Uma loja de verdade, e nao um duplo: o duplo anterior fazia `delete`
  # devolver o valor guardado, coisa que cache nenhum faz — e por isso o teste
  # passava enquanto ligar uma agenda falhava sempre.
  it 'uses a one-time cached state for the Google callback' do
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
    state = SecureRandom.urlsafe_base64(24)
    Rails.cache.write(
      described_class.state_cache_key(state),
      { 'resource_id' => resource.id, 'account_id' => account.id }
    )

    expect(described_class.resource_from_state!(state)).to eq(resource)
    expect { described_class.resource_from_state!(state) }
      .to raise_error(KanbanCalendar::GoogleCalendarApiError, 'Google authorization expired')
  end

  # A ida e volta inteira, sem escrever o `state` à mão. O teste de cima monta
  # a primeira metade sozinho e por isso nunca executou `authorization_url`: foi
  # assim que um NoMethodError ali chegou a produção e deu 500 no primeiro
  # clique depois de as credenciais serem configuradas.
  it 'starts an authorization whose state leads the callback back to the same agenda' do
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
    {
      'GOOGLE_CALENDAR_OAUTH_CLIENT_ID' => 'client-id',
      'GOOGLE_CALENDAR_OAUTH_CLIENT_SECRET' => 'client-secret',
      'GOOGLE_CALENDAR_OAUTH_CALLBACK_URL' => 'https://crm.example.com/calendar/google/callback'
    }.each do |name, value|
      config = InstallationConfig.find_or_initialize_by(name: name)
      config.value = value
      config.locked = false
      config.save!
    end
    GlobalConfig.clear_cache

    url = described_class.new(resource: resource).authorization_url
    query = Rack::Utils.parse_query(URI.parse(url).query)

    expect(query).to include(
      'client_id' => 'client-id',
      'scope' => described_class::SCOPE,
      'redirect_uri' => 'https://crm.example.com/calendar/google/callback',
      'access_type' => 'offline'
    )
    expect(described_class.resource_from_state!(query['state'])).to eq(resource)
  end

  it 'queues the export and the Google import after connecting an agenda' do
    connection = instance_double(KanbanCalendarGoogleConnection, refresh_token: 'old-refresh-token')
    token = instance_double(
      OAuth2::AccessToken,
      to_hash: { access_token: 'access-token', refresh_token: 'refresh-token', expires_at: 1.hour.from_now.to_i,
                 scope: 'https://www.googleapis.com/auth/calendar.events' }
    )
    client = instance_double(OAuth2::Client)
    authorization = instance_double(OAuth2::Strategy::AuthCode)
    allow(client).to receive(:auth_code).and_return(authorization)
    allow(authorization).to receive(:get_token).and_return(token)
    allow(resource).to receive(:kanban_calendar_google_connection).and_return(connection)
    allow(connection).to receive(:update!)
    allow(connection).to receive(:id).and_return(16)
    allow(KanbanCalendar::BackfillGoogleCalendarConnectionJob).to receive(:perform_later)
    allow(KanbanCalendar::ImportGoogleCalendarEventsJob).to receive(:perform_later)
    service = described_class.new(resource: resource)
    allow(service).to receive(:oauth_client).and_return(client)

    service.connect!('authorization-code')

    expect(KanbanCalendar::BackfillGoogleCalendarConnectionJob).to have_received(:perform_later).with(16)
    expect(KanbanCalendar::ImportGoogleCalendarEventsJob).to have_received(:perform_later).with(16)
  end

  # O Google mostra a permissão da agenda como uma caixa de seleção. Desmarcada, a
  # ligação parecia feita e cada envio falhava depois, longe de quem ligou.
  it 'refuses to connect when the calendar permission was left unchecked on Google' do
    token = instance_double(
      OAuth2::AccessToken,
      to_hash: { access_token: 'access-token', refresh_token: 'refresh-token', expires_at: 1.hour.from_now.to_i, scope: 'openid' }
    )
    client = instance_double(OAuth2::Client)
    authorization = instance_double(OAuth2::Strategy::AuthCode, get_token: token)
    allow(client).to receive(:auth_code).and_return(authorization)
    service = described_class.new(resource: resource)
    allow(service).to receive(:oauth_client).and_return(client)

    expect { service.connect!('authorization-code') }.to raise_error(KanbanCalendar::GoogleCalendarPermissionError)
    expect(resource.reload.kanban_calendar_google_connection).to be_nil
  end
end
