require 'rails_helper'

RSpec.describe 'Calendar schedules API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:base) { "/api/v1/accounts/#{account.id}/calendar" }
  let(:week) { (1..5).map { |weekday| { weekday: weekday, ranges: [{ from: '08:00', to: '18:00' }] } } }

  it 'creates a named schedule with its week and marks it as the account default' do
    post "#{base}/schedules",
         params: { schedule: { name: 'Comercial', timezone: 'America/Recife', default_schedule: true }, weekly: week },
         headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body.slice('name', 'default', 'resources_count')).to eq('name' => 'Comercial', 'default' => true, 'resources_count' => 0)
    expect(response.parsed_body['weekly'].length).to eq(5)
  end

  it 'lets agents read schedules but only administrators change them' do
    get "#{base}/schedules", headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:success)

    post "#{base}/schedules", params: { schedule: { name: 'X', timezone: 'UTC' } }, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  it 'warns how many future appointments fall outside before applying, then applies to the agendas' do
    schedule = account.kanban_calendar_schedules.create!(name: 'Manhãs', timezone: 'America/Sao_Paulo')
    KanbanCalendar::WorkingHoursSheet.new(schedule.kanban_calendar_availability_rules)
                                     .replace!(weekly: (0..6).map { |day| { weekday: day, ranges: [{ from: '08:00', to: '12:00' }] } }, overrides: [])
    agenda = KanbanCalendarResource.create!(account: account, name: 'Dra. Anna', resource_type: 'user', timezone: 'America/Sao_Paulo')
    agenda.kanban_calendar_availability_rules.delete_all
    (0..6).each do |day|
      agenda.kanban_calendar_availability_rules.create!(kind: 'weekly_window', weekday: day, starts_at_local: '08:00', ends_at_local: '18:00')
    end
    procedure = KanbanCalendarProcedure.create!(account: account, name: 'Consulta', duration_minutes: 60)
    afternoon = 3.days.from_now.in_time_zone('America/Sao_Paulo').change(hour: 15)
    KanbanCalendar::BookAppointmentService.new(account: account, contact: create(:contact, account: account), procedure: procedure,
                                               resource_ids: [agenda.id], starts_at: afternoon, timezone: 'America/Sao_Paulo').perform!

    post "#{base}/schedules/#{schedule.id}/apply_to", params: { resource_ids: [agenda.id], dry_run: true },
                                                      headers: administrator.create_new_auth_token, as: :json
    expect(response.parsed_body).to eq('appointments_outside' => 1)
    expect(agenda.reload.kanban_calendar_schedule).to be_nil

    post "#{base}/schedules/#{schedule.id}/apply_to", params: { resource_ids: [agenda.id] }, headers: administrator.create_new_auth_token, as: :json
    expect(agenda.reload.kanban_calendar_schedule).to eq(schedule)
    expect(response.parsed_body['resources']).to eq([{ 'id' => agenda.id, 'name' => 'Dra. Anna' }])
  end

  it 'refuses to delete a schedule that agendas still use' do
    schedule = account.kanban_calendar_schedules.create!(name: 'Comercial', timezone: 'America/Sao_Paulo')
    KanbanCalendarResource.create!(account: account, name: 'Sala 1', resource_type: 'room', timezone: 'America/Sao_Paulo',
                                   kanban_calendar_schedule: schedule)

    delete "#{base}/schedules/#{schedule.id}", headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['resources_count']).to eq(1)
  end

  it 'replaces the week and exceptions of a schedule' do
    schedule = account.kanban_calendar_schedules.create!(name: 'Comercial', timezone: 'America/Sao_Paulo')

    put "#{base}/schedules/#{schedule.id}/rules",
        params: {
          weekly: [{ weekday: 1, ranges: [{ from: '08:00', to: '12:00' }] }],
          overrides: [{ date: '2026-10-07', closed: true, note: 'Congresso' }]
        },
        headers: administrator.create_new_auth_token, as: :json

    expect(response.parsed_body['overrides']).to eq([{ 'date' => '2026-10-07', 'closed' => true, 'note' => 'Congresso' }])
  end

  it 'gives an agenda that leaves a named schedule the week it was using, and says when an agenda has no hours' do
    schedule = account.kanban_calendar_schedules.create!(name: 'Comercial', timezone: 'America/Sao_Paulo', default_schedule: true)
    KanbanCalendar::WorkingHoursSheet.new(schedule.kanban_calendar_availability_rules)
                                     .replace!(weekly: [{ weekday: 2, ranges: [{ from: '09:00', to: '13:00' }] }], overrides: [])
    agenda = KanbanCalendarResource.create!(account: account, name: 'Sala 2', resource_type: 'room', timezone: 'America/Sao_Paulo')
    expect(agenda.kanban_calendar_schedule).to eq(schedule)

    patch "#{base}/resources/#{agenda.id}", params: { resource: { schedule_id: nil } }, headers: administrator.create_new_auth_token, as: :json

    expect(response.parsed_body.slice('schedule', 'missing_hours')).to eq('schedule' => nil, 'missing_hours' => false)
    get "#{base}/resources/#{agenda.id}/working_hours", headers: administrator.create_new_auth_token, as: :json
    expect(response.parsed_body['weekly']).to eq([{ 'weekday' => 2, 'ranges' => [{ 'from' => '09:00', 'to' => '13:00' }] }])

    put "#{base}/resources/#{agenda.id}/working_hours", params: { weekly: [], overrides: [] }, headers: administrator.create_new_auth_token, as: :json
    get "#{base}/resources", headers: administrator.create_new_auth_token, as: :json
    expect(response.parsed_body.find { |item| item['id'] == agenda.id }['missing_hours']).to be(true)
  end

  it 'creates an agenda with hours of its own even when the account has a default schedule' do
    schedule = account.kanban_calendar_schedules.create!(name: 'Comercial', timezone: 'America/Sao_Paulo', default_schedule: true)
    KanbanCalendar::WorkingHoursSheet.new(schedule.kanban_calendar_availability_rules)
                                     .replace!(weekly: [{ weekday: 1, ranges: [{ from: '08:00', to: '18:00' }] }], overrides: [])

    post "#{base}/resources",
         params: { resource: { name: 'Sala 2', resource_type: 'room', timezone: 'America/Sao_Paulo', schedule_id: nil } },
         headers: administrator.create_new_auth_token, as: :json

    agenda = KanbanCalendarResource.find(response.parsed_body['id'])
    expect(agenda.kanban_calendar_schedule).to be_nil
    expect(agenda.kanban_calendar_availability_rules.pluck(:weekday)).to eq([1])
  end
end
