require 'rails_helper'

RSpec.describe 'Calendar teams API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:base) { "/api/v1/accounts/#{account.id}/calendar/teams" }
  let(:anna) { KanbanCalendarResource.create!(account: account, name: 'Dra. Anna', resource_type: 'user', timezone: 'America/Sao_Paulo') }
  let(:bruno) { KanbanCalendarResource.create!(account: account, name: 'Dr. Bruno', resource_type: 'user', timezone: 'America/Sao_Paulo') }
  let(:sala) { KanbanCalendarResource.create!(account: account, name: 'Sala 1', resource_type: 'room', timezone: 'America/Sao_Paulo') }

  it 'creates a team with its professionals and distribution rule' do
    post base, params: { team: { name: 'Dermatologia', assignment_strategy: 'round_robin' }, member_ids: [anna.id, bruno.id] },
               headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body['members'].pluck('name')).to eq(['Dr. Bruno', 'Dra. Anna'])
    expect(response.parsed_body['assignment_strategy']).to eq('round_robin')
  end

  it 'refuses a room as a team member' do
    post base, params: { team: { name: 'Salas' }, member_ids: [sala.id] }, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(account.kanban_calendar_teams.count).to eq(0)
  end

  it 'keeps the round robin place of members who stay' do
    team = account.kanban_calendar_teams.create!(name: 'Dermatologia')
    team.kanban_calendar_team_members.create!(kanban_calendar_resource: anna, last_assigned_at: 2.days.ago)
    team.kanban_calendar_team_members.create!(kanban_calendar_resource: bruno)

    patch "#{base}/#{team.id}", params: { team: { name: 'Dermatologia' }, member_ids: [anna.id] }, headers: administrator.create_new_auth_token,
                                as: :json

    expect(team.kanban_calendar_team_members.pluck(:kanban_calendar_resource_id)).to eq([anna.id])
    expect(team.kanban_calendar_team_members.first.last_assigned_at).to be_present
  end
end
