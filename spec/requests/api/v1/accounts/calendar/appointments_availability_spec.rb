require 'rails_helper'

RSpec.describe 'Calendar appointment availability', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:timezone) { 'America/Sao_Paulo' }
  let(:date) { Date.new(2026, 8, 10) }
  let(:procedure) { KanbanCalendarProcedure.create!(account: account, name: 'Toxina', duration_minutes: 50) }
  let(:professional) do
    KanbanCalendarResource.create!(account: account, name: 'Dra. Ana', resource_type: 'user', timezone: timezone)
  end
  let(:room) do
    KanbanCalendarResource.create!(account: account, name: 'Sala 1', resource_type: 'room', timezone: timezone)
  end
  let(:path) { "/api/v1/accounts/#{account.id}/calendar/appointments/availability" }

  before do
    professional.kanban_calendar_availability_rules.create!(
      kind: 'weekly_window', weekday: date.wday, starts_at_local: '09:00', ends_at_local: '11:00'
    )
    room.kanban_calendar_availability_rules.create!(
      kind: 'weekly_window', weekday: date.wday, starts_at_local: '10:00', ends_at_local: '12:00'
    )
  end

  def local_times
    response.parsed_body['slots'].map { |slot| Time.iso8601(slot).in_time_zone(timezone).strftime('%H:%M') }
  end

  it 'offers only the starts where the professional and the room are both free' do
    get path,
        params: { procedure_id: procedure.id, resource_ids: [professional.id, room.id], date: date.iso8601 },
        headers: administrator.create_new_auth_token

    expect(response).to have_http_status(:ok)
    expect(local_times).to eq(['10:00'])
  end

  # A oportunidade do Kanban e o runtime continuam a perguntar por um recurso só.
  it 'still answers for a single resource_id' do
    get path,
        params: { procedure_id: procedure.id, resource_id: professional.id, date: date.iso8601 },
        headers: administrator.create_new_auth_token

    expect(response).to have_http_status(:ok)
    expect(local_times).to eq(['09:00', '09:15', '09:30', '09:45', '10:00'])
  end

  it 'refuses a resource from another account instead of ignoring it' do
    foreign = KanbanCalendarResource.create!(
      account: create(:account), name: 'Sala alheia', resource_type: 'room', timezone: timezone
    )

    get path,
        params: { procedure_id: procedure.id, resource_ids: [professional.id, foreign.id], date: date.iso8601 },
        headers: administrator.create_new_auth_token

    expect(response).to have_http_status(:not_found)
  end
end
