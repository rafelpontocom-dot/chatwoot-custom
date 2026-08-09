require 'rails_helper'

RSpec.describe KanbanCalendar::GoogleCalendarSyncService do
  let(:connection) do
    instance_double(
      KanbanCalendarGoogleConnection,
      id: 14,
      connected?: true,
      update!: true,
      last_error: nil
    )
  end
  let(:appointment) do
    instance_double(
      KanbanCalendarAppointment,
      id: 62,
      account: instance_double(Account),
      status: 'scheduled',
      external_refs: {},
      update!: true,
      kanban_calendar_appointment_events: instance_double(ActiveRecord::Associations::CollectionProxy, create!: true)
    )
  end
  let(:client) { instance_double(KanbanCalendar::GoogleCalendarClient) }

  it 'creates an external event and stores its id on the appointment' do
    allow(client).to receive(:create_event).with(appointment).and_return('google-event-1')

    described_class.new(appointment: appointment, connection: connection, client: client).perform!

    expect(appointment).to have_received(:update!).with(
      external_refs: { 'google_calendar' => { '14' => 'google-event-1' } }
    )
    expect(connection).to have_received(:update!).with(status: 'connected', last_error: nil, last_synced_at: kind_of(Time))
  end

  it 'cancels an existing Google event instead of creating another one' do
    allow(appointment).to receive(:status).and_return('canceled')
    allow(appointment).to receive(:external_refs).and_return({ 'google_calendar' => { '14' => 'google-event-1' } })
    allow(client).to receive(:create_event)
    allow(client).to receive(:cancel_event).with('google-event-1')

    described_class.new(appointment: appointment, connection: connection, client: client).perform!

    expect(client).to have_received(:cancel_event).with('google-event-1')
    expect(client).not_to have_received(:create_event)
  end

  it 'marks the connection as errored when Google rejects the export' do
    allow(client).to receive(:create_event).and_raise(
      KanbanCalendar::GoogleCalendarApiError,
      'Google access was revoked'
    )

    expect do
      described_class.new(appointment: appointment, connection: connection, client: client).perform!
    end.to raise_error(KanbanCalendar::GoogleCalendarApiError, 'Google access was revoked')

    expect(connection).to have_received(:update!).with(
      status: 'error',
      last_error: 'Google access was revoked'
    )
  end
end
