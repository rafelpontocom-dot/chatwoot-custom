require 'rails_helper'

RSpec.describe KanbanCalendar::ImportAllGoogleCalendarsJob do
  let(:account) { create(:account) }

  def connection(name, status, tokens: status != 'disconnected')
    resource = KanbanCalendarResource.create!(account: account, name: name, resource_type: 'user', timezone: 'America/Sao_Paulo')
    attributes = tokens ? { access_token: 'token', refresh_token: 'refresh', expires_at: 1.hour.from_now } : {}
    KanbanCalendarGoogleConnection.create!(account: account, kanban_calendar_resource: resource, status: status, **attributes)
  end

  # Uma falha passageira punha a ligação em «error», e «error» nunca mais era
  # tentado: a agenda ficava parada até alguém sincronizar à mão (17/10).
  it 'queues an import for connected agendas and retries the ones in error' do
    connected = connection('Dra. Ana', 'connected')
    failed = connection('Sala 1', 'error')
    switched_off = connection('Dr. Bruno', 'disconnected')
    without_credentials = connection('Sala 2', 'error', tokens: false)

    expect { described_class.perform_now }
      .to have_enqueued_job(KanbanCalendar::ImportGoogleCalendarEventsJob).with(connected.id).exactly(:once)
      .and have_enqueued_job(KanbanCalendar::ImportGoogleCalendarEventsJob).with(failed.id).exactly(:once)

    described_class.perform_now
    queued = ActiveJob::Base.queue_adapter.enqueued_jobs
                            .select { |job| job['job_class'] == 'KanbanCalendar::ImportGoogleCalendarEventsJob' }
                            .flat_map { |job| job['arguments'] }
    expect(queued).not_to include(switched_off.id, without_credentials.id)
  end
end
