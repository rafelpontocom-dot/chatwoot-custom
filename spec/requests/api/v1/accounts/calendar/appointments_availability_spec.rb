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
    # A agenda nasce com a semana comercial; estes exemplos definem a sua.
    [professional, room].each { |resource| resource.kanban_calendar_availability_rules.delete_all }
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

  # Agenda sem horários não oferece horário nenhum, e a lista vazia não explicava
  # porquê: era o que o Alysson via ao escolher a sua agenda.
  it 'names the agendas without working hours instead of answering an empty list in silence' do
    room.kanban_calendar_availability_rules.delete_all

    get path,
        params: { procedure_id: procedure.id, resource_ids: [professional.id, room.id], date: date.iso8601 },
        headers: administrator.create_new_auth_token

    expect(response.parsed_body['slots']).to be_empty
    expect(response.parsed_body['resources_without_hours']).to eq([{ 'id' => room.id, 'name' => 'Sala 1' }])
  end

  it 'says nothing about working hours when every agenda has them' do
    get path,
        params: { procedure_id: procedure.id, resource_ids: [professional.id, room.id], date: date.iso8601 },
        headers: administrator.create_new_auth_token

    expect(response.parsed_body['resources_without_hours']).to eq([])
  end

  # Sem data escolhida a tela não tinha o que mostrar, e quem marca ficava a
  # adivinhar. Escolher as agendas passa a bastar para ver os próximos horários.
  it 'answers with the next days that have room when no date is asked for' do
    get path,
        params: { procedure_id: procedure.id, resource_ids: [professional.id, room.id], days: 7, from: date.iso8601 },
        headers: administrator.create_new_auth_token

    expect(response).to have_http_status(:ok)
    dias = response.parsed_body['days']
    expect(dias.first['date']).to eq(date.iso8601)
    expect(dias.first['slots'].map { |slot| Time.iso8601(slot).in_time_zone(timezone).strftime('%H:%M') }).to eq(['10:00'])
    expect(response.parsed_body['resources_without_hours']).to eq([])
  end

  it 'still answers a single day when the date is given' do
    get path,
        params: { procedure_id: procedure.id, resource_ids: [professional.id, room.id], date: date.iso8601 },
        headers: administrator.create_new_auth_token

    expect(response.parsed_body).to have_key('slots')
    expect(response.parsed_body).not_to have_key('days')
  end
end
