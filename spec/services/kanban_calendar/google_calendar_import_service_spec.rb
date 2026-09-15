require 'rails_helper'

RSpec.describe KanbanCalendar::GoogleCalendarImportService do
  let(:account) { create(:account) }
  let(:resource) do
    KanbanCalendarResource.create!(account: account, name: 'Dra. Ana', resource_type: 'user', timezone: 'America/Sao_Paulo')
  end
  let(:connection) do
    KanbanCalendarGoogleConnection.create!(
      account: account, kanban_calendar_resource: resource, status: 'connected',
      access_token: 'token', refresh_token: 'refresh', expires_at: 1.hour.from_now
    )
  end
  let(:client) { instance_double(KanbanCalendar::GoogleCalendarClient) }
  let(:now) { Time.zone.parse('2026-09-15 12:00:00') }

  def event(id, starts, ends, **extra)
    { 'id' => id, 'status' => 'confirmed', 'start' => { 'dateTime' => starts }, 'end' => { 'dateTime' => ends } }.merge(extra)
  end

  def import(items)
    allow(client).to receive(:list_events).and_return({ items: items, time_zone: 'America/Sao_Paulo' })
    described_class.new(connection: connection, client: client, now: now).perform!
  end

  it 'turns busy Google events into blocks of the connected resource, without keeping the title' do
    import([event('consulta-externa', '2026-09-16T10:00:00-03:00', '2026-09-16T11:30:00-03:00', 'summary' => 'Dentista')])

    expect(connection.kanban_calendar_external_busy_blocks.sole).to have_attributes(
      account_id: account.id,
      kanban_calendar_resource_id: resource.id,
      external_event_id: 'consulta-externa',
      starts_at: Time.zone.parse('2026-09-16 13:00:00'),
      ends_at: Time.zone.parse('2026-09-16 14:30:00'),
      all_day: false
    )
    expect(connection.reload.last_imported_at).to be_present
  end

  it 'ignores what does not make the person busy, and what the Raevo itself sent' do
    import([
             event('livre', '2026-09-16T10:00:00-03:00', '2026-09-16T11:00:00-03:00', 'transparency' => 'transparent'),
             event('cancelado', '2026-09-16T10:00:00-03:00', '2026-09-16T11:00:00-03:00', 'status' => 'cancelled'),
             event('recusado', '2026-09-16T10:00:00-03:00', '2026-09-16T11:00:00-03:00',
                   'attendees' => [{ 'self' => true, 'responseStatus' => 'declined' }]),
             event('local-de-trabalho', '2026-09-16T08:00:00-03:00', '2026-09-16T18:00:00-03:00', 'eventType' => 'workingLocation'),
             event('do-raevo', '2026-09-16T10:00:00-03:00', '2026-09-16T11:00:00-03:00',
                   'extendedProperties' => { 'private' => { 'raevo_appointment_id' => '15' } })
           ])

    expect(connection.kanban_calendar_external_busy_blocks).to be_empty
  end

  it 'blocks a whole all-day event in the calendar time zone' do
    import([{ 'id' => 'ferias', 'status' => 'confirmed', 'start' => { 'date' => '2026-09-20' }, 'end' => { 'date' => '2026-09-22' } }])

    expect(connection.kanban_calendar_external_busy_blocks.sole).to have_attributes(
      starts_at: Time.zone.parse('2026-09-20 03:00:00'),
      ends_at: Time.zone.parse('2026-09-22 03:00:00'),
      all_day: true
    )
  end

  it 'moves a changed event and removes one deleted in Google' do
    import([event('movido', '2026-09-16T10:00:00-03:00', '2026-09-16T11:00:00-03:00'),
            event('apagado', '2026-09-17T10:00:00-03:00', '2026-09-17T11:00:00-03:00')])

    import([event('movido', '2026-09-16T15:00:00-03:00', '2026-09-16T16:00:00-03:00')])

    expect(connection.kanban_calendar_external_busy_blocks.pluck(:external_event_id, :starts_at)).to eq(
      [['movido', Time.zone.parse('2026-09-16 18:00:00')]]
    )
  end

  it 'records the Google error on the connection so the settings can show it' do
    allow(client).to receive(:list_events).and_raise(KanbanCalendar::GoogleCalendarApiError, 'Request had insufficient authentication scopes.')

    expect { described_class.new(connection: connection, client: client, now: now).perform! }
      .to raise_error(KanbanCalendar::GoogleCalendarApiError)
    expect(connection.reload).to have_attributes(status: 'error', last_error: 'Request had insufficient authentication scopes.')
  end
end
