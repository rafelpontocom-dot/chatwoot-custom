require 'rails_helper'

RSpec.describe KanbanCalendar::ImportAllFeegowCalendarsJob do
  def connection(status, token: 'token')
    KanbanCalendarFeegowConnection.create!(account: create(:account), api_url: 'https://api.feegow.com/v1/api', status: status, api_token: token)
  end

  # O Feegow da Dra. Anna falhou uma vez a 08/10 e ficou em «error»; como só
  # «connected» era importado, a agenda ficou nove dias sem bloqueios novos.
  it 'queues an import for connected clinics and retries the ones in error' do
    connected = connection('connected')
    failed = connection('error')
    switched_off = connection('disconnected')
    without_credentials = connection('error', token: nil)

    expect { described_class.perform_now }
      .to have_enqueued_job(KanbanCalendar::ImportFeegowCalendarJob).with(connected.id).exactly(:once)
      .and have_enqueued_job(KanbanCalendar::ImportFeegowCalendarJob).with(failed.id).exactly(:once)

    described_class.perform_now
    queued = ActiveJob::Base.queue_adapter.enqueued_jobs
                            .select { |job| job['job_class'] == 'KanbanCalendar::ImportFeegowCalendarJob' }
                            .flat_map { |job| job['arguments'] }
    expect(queued).not_to include(switched_off.id, without_credentials.id)
  end
end
