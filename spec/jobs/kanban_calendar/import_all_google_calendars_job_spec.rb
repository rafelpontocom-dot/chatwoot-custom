require 'rails_helper'

RSpec.describe KanbanCalendar::ImportAllGoogleCalendarsJob do
  let(:account) { create(:account) }

  def connection(name, status)
    resource = KanbanCalendarResource.create!(account: account, name: name, resource_type: 'user', timezone: 'America/Sao_Paulo')
    attributes = status == 'connected' ? { access_token: 'token', refresh_token: 'refresh', expires_at: 1.hour.from_now } : {}
    KanbanCalendarGoogleConnection.create!(account: account, kanban_calendar_resource: resource, status: status, **attributes)
  end

  it 'queues an import for each connected agenda only' do
    connected = connection('Dra. Ana', 'connected')
    connection('Dr. Bruno', 'disconnected')
    connection('Sala 1', 'error')

    expect { described_class.perform_now }.to have_enqueued_job(KanbanCalendar::ImportGoogleCalendarEventsJob).with(connected.id).exactly(:once)
  end
end
