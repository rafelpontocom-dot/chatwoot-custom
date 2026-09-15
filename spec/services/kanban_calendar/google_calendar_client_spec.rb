require 'rails_helper'

RSpec.describe KanbanCalendar::GoogleCalendarClient do
  let(:connection) do
    instance_double(KanbanCalendarGoogleConnection, calendar_id: 'primary', token_expired?: false, access_token: 'token')
  end
  let(:events_url) { 'https://www.googleapis.com/calendar/v3/calendars/primary/events' }
  let(:time_min) { Time.zone.parse('2026-09-14 00:00:00') }
  let(:time_max) { Time.zone.parse('2026-12-14 00:00:00') }

  it 'lists every page of expanded events in the window with the calendar time zone' do
    stub_request(:get, events_url)
      .with(query: hash_including('singleEvents' => 'true', 'timeMin' => time_min.iso8601, 'timeMax' => time_max.iso8601),
            headers: { 'Authorization' => 'Bearer token' })
      .to_return(
        { status: 200, body: { timeZone: 'America/Sao_Paulo', items: [{ id: 'a' }], nextPageToken: 'p2' }.to_json },
        { status: 200, body: { timeZone: 'America/Sao_Paulo', items: [{ id: 'b' }] }.to_json }
      )

    result = described_class.new(connection: connection).list_events(time_min: time_min, time_max: time_max)

    expect(result[:items].pluck('id')).to eq(%w[a b])
    expect(result[:time_zone]).to eq('America/Sao_Paulo')
    expect(a_request(:get, events_url).with(query: hash_including('pageToken' => 'p2'))).to have_been_made.once
  end

  it 'raises the Google message when the calendar cannot be read' do
    stub_request(:get, events_url).with(query: hash_including({}))
                                  .to_return(status: 403, body: { error: { message: 'Request had insufficient authentication scopes.' } }.to_json)

    expect do
      described_class.new(connection: connection).list_events(time_min: time_min, time_max: time_max)
    end.to raise_error(KanbanCalendar::GoogleCalendarApiError, 'Request had insufficient authentication scopes.')
  end
end
