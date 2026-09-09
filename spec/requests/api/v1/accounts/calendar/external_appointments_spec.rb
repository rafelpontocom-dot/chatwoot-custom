require 'rails_helper'

RSpec.describe 'External calendar appointments', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:contact) { create(:contact, account: account) }
  let(:procedure) do
    KanbanCalendarProcedure.create!(account: account, name: 'Consulta', duration_minutes: 50, recurrence_allowed: false)
  end
  let(:resource) do
    KanbanCalendarResource.create!(
      account: account, name: 'Dra. Anna', resource_type: 'generic', timezone: 'America/Sao_Paulo'
    )
  end
  let(:appointment) do
    KanbanCalendar::BookAppointmentService.new(
      account: account,
      contact: contact,
      procedure: procedure,
      resource_ids: [resource.id],
      starts_at: Time.iso8601('2026-10-01T13:00:00-03:00'),
      timezone: 'America/Sao_Paulo',
      actor: nil
    ).perform!.tap do |record|
      record.update!(source_provider: 'feegow', source_external_id: '630', source_read_only: true)
    end
  end

  it 'rejects local status changes for an externally authoritative projection' do
    patch "/api/v1/accounts/#{account.id}/calendar/appointments/#{appointment.id}", params: {
      appointment: { action: 'confirm', lock_version: appointment.lock_version }
    }, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['message']).to include('Feegow')
  end

  it 'rejects local rescheduling for an externally authoritative projection' do
    post "/api/v1/accounts/#{account.id}/calendar/appointments/#{appointment.id}/reschedule", params: {
      appointment: {
        starts_at: '2026-10-02T13:00:00-03:00',
        resource_ids: [resource.id],
        scope: 'this_occurrence',
        lock_version: appointment.lock_version
      }
    }, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['message']).to include('Feegow')
    expect(appointment.reload.starts_at).to eq(Time.iso8601('2026-10-01T13:00:00-03:00'))
  end
end
