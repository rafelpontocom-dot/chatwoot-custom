require 'rails_helper'

# 5m: as tarefas dos leads na Agenda são as próximas ações abertas das
# oportunidades, no período que a grelha mostra, mais as que já passaram.
RSpec.describe 'Kanban next actions API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:colleague) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:board) { create(:kanban_board, account: account, name: 'Captação') }
  let(:stage) { create(:kanban_stage, account: account, kanban_board: board, name: 'Lead') }
  let(:week) { { starts_at: '2026-10-05T03:00:00Z', ends_at: '2026-10-12T03:00:00Z' } }

  before do
    create(:inbox_member, user: agent, inbox: inbox)
    travel_to Time.zone.parse('2026-10-08T15:00:00Z')
  end

  def card(**attributes)
    create(:kanban_card, account: account, kanban_board: board, kanban_stage: stage, inbox: inbox, owner: agent,
                         contact: create(:contact, account: account, name: 'Gina Torres'), **attributes)
  end

  def get_next_actions(params = week, user: agent)
    get "/api/v1/accounts/#{account.id}/kanban_next_actions", params: params, headers: user.create_new_auth_token, as: :json
  end

  it 'returns unauthorized without a session' do
    get "/api/v1/accounts/#{account.id}/kanban_next_actions", params: week

    expect(response).to have_http_status(:unauthorized)
  end

  it 'lists my open next actions in the period, with what the grid needs' do
    task = card(next_action_type: 'Ligar', next_action_at: Time.zone.parse('2026-10-09T13:00:00Z'),
                next_action_note: 'Confirmar avaliação', subject: 'Gina — avaliação')
    card(next_action_type: 'Ligar', next_action_at: Time.zone.parse('2026-10-20T13:00:00Z'))
    card(next_action_type: 'Ligar', next_action_at: Time.zone.parse('2026-10-09T14:00:00Z'), owner: colleague)
    card(next_action_type: 'Ligar', next_action_at: Time.zone.parse('2026-10-09T15:00:00Z'), won_at: Time.current)
    card(next_action_type: 'Ligar', next_action_at: Time.zone.parse('2026-10-09T16:00:00Z'), active: false,
         archived_at: Time.current)

    get_next_actions

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['tasks']).to contain_exactly(
      include(
        'kanban_card_id' => task.id, 'kanban_board_id' => board.id, 'kanban_board_name' => 'Captação',
        'kanban_stage_name' => 'Lead', 'subject' => 'Gina — avaliação', 'contact_name' => 'Gina Torres',
        'next_action_type' => 'Ligar', 'next_action_note' => 'Confirmar avaliação',
        'next_action_at' => '2026-10-09T13:00:00Z'
      )
    )
  end

  it 'includes the team when asked, but never a board the agent cannot see' do
    mine = card(next_action_at: Time.zone.parse('2026-10-09T13:00:00Z'))
    theirs = card(next_action_at: Time.zone.parse('2026-10-09T14:00:00Z'), owner: colleague)
    hidden_board = create(:kanban_board, account: account, visibility_mode: 'selected_agents')
    create(:kanban_card, account: account, kanban_board: hidden_board, inbox: inbox, owner: colleague,
                         next_action_at: Time.zone.parse('2026-10-09T15:00:00Z'))

    get_next_actions(week.merge(scope: 'team'))

    expect(response.parsed_body['tasks'].pluck('kanban_card_id')).to eq([mine.id, theirs.id])
  end

  it 'counts the overdue ones apart from the period' do
    late = card(next_action_type: 'WhatsApp', next_action_at: Time.zone.parse('2026-09-30T13:00:00Z'))
    card(next_action_at: Time.zone.parse('2026-10-01T13:00:00Z'), next_action_completed_at: Time.current)
    card(next_action_at: Time.zone.parse('2026-10-09T13:00:00Z'))

    get_next_actions

    expect(response.parsed_body['overdue']).to include('count' => 1)
    expect(response.parsed_body['overdue']['items'].pluck('kanban_card_id')).to eq([late.id])
  end

  it 'refuses a period it cannot read' do
    get_next_actions({ starts_at: 'ontem', ends_at: week[:ends_at] })

    expect(response).to have_http_status(:unprocessable_entity)
  end
end
