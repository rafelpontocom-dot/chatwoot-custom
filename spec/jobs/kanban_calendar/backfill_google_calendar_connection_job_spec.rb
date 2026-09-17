require 'rails_helper'

RSpec.describe KanbanCalendar::BackfillGoogleCalendarConnectionJob do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:resource) do
    KanbanCalendarResource.create!(account: account, name: 'Dra. Ana', resource_type: 'user', timezone: 'America/Sao_Paulo')
  end
  let(:procedure) { KanbanCalendarProcedure.create!(account: account, name: 'Consulta', duration_minutes: 50) }
  let(:connection) do
    KanbanCalendarGoogleConnection.create!(
      account: account, kanban_calendar_resource: resource, status: 'connected',
      access_token: 'token', refresh_token: 'refresh', expires_at: 1.hour.from_now
    )
  end

  # Numa quarta: «daqui a dois dias» e «há dois dias» caem em dias úteis, dentro
  # do horário padrão da agenda. Sem data fixa, o teste falhava perto do fim de semana.
  around { |example| travel_to(Time.zone.local(2026, 9, 16, 12)) { example.run } }

  def book(starts_at)
    KanbanCalendar::BookAppointmentService.new(
      account: account, contact: contact, procedure: procedure, resource_ids: [resource.id],
      starts_at: starts_at, timezone: 'America/Sao_Paulo', dispatch_events: false
    ).perform!
  end

  it 'skips a disconnected Google Calendar connection' do
    connection.update!(status: 'disconnected', access_token: nil, refresh_token: nil, expires_at: nil)
    allow(KanbanCalendar::GoogleCalendarSyncService).to receive(:new)

    described_class.perform_now(connection.id)

    expect(KanbanCalendar::GoogleCalendarSyncService).not_to have_received(:new)
  end

  # Corria só com dublês e nunca executou a consulta: na base real, `ends_at`
  # existe nas consultas e nas reservas, e o Postgres recusava a coluna ambígua.
  # Ligar a agenda rebentava sempre e nenhuma consulta existente ia para o Google.
  it 'exports the future appointments of the connected resource, and only those' do
    future = book(2.days.from_now.change(hour: 13))
    book(2.days.ago.change(hour: 13))
    sync = instance_double(KanbanCalendar::GoogleCalendarSyncService, perform!: true)
    allow(KanbanCalendar::GoogleCalendarSyncService).to receive(:new).and_return(sync)

    described_class.perform_now(connection.id)

    expect(KanbanCalendar::GoogleCalendarSyncService).to have_received(:new).once
                                                                            .with(appointment: future, connection: connection)
  end
end
