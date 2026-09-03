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

  it 'queues a backfill after connecting an agenda' do
    connection = instance_double(KanbanCalendarGoogleConnection, refresh_token: 'old-refresh-token')
    token = instance_double(
      OAuth2::AccessToken,
      to_hash: { access_token: 'access-token', refresh_token: 'refresh-token', expires_at: 1.hour.from_now.to_i }
    )
    client = instance_double(OAuth2::Client)
    authorization = instance_double(OAuth2::Strategy::AuthCode)
    allow(client).to receive(:auth_code).and_return(authorization)
    allow(authorization).to receive(:get_token).and_return(token)
    allow(resource).to receive(:kanban_calendar_google_connection).and_return(connection)
    allow(connection).to receive(:update!)
    allow(connection).to receive(:id).and_return(16)
    allow(KanbanCalendar::BackfillGoogleCalendarConnectionJob).to receive(:perform_later)
    service = described_class.new(resource: resource)
    allow(service).to receive(:oauth_client).and_return(client)

    service.connect!('authorization-code')

    expect(KanbanCalendar::BackfillGoogleCalendarConnectionJob).to have_received(:perform_later).with(16)
  end
end
