require 'rails_helper'

RSpec.describe 'Kanban cadence enrollment API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:board) { create(:kanban_board, account: account) }
  let(:stage) { create(:kanban_stage, account: account, kanban_board: board) }
  let(:card) { create(:kanban_card, account: account, kanban_board: board, kanban_stage: stage) }
  let(:cadence) { create(:kanban_cadence, account: account, kanban_board: board) }

  before do
    create(:inbox_member, user: agent, inbox: card.inbox)
  end

  def cadence_url
    "/api/v1/accounts/#{account.id}/kanban_boards/#{board.id}/cards/by_id/#{card.id}/cadence"
  end

  it 'enrolls an agent-visible opportunity in a cadence and allows cancellation' do
    post cadence_url,
         headers: agent.create_new_auth_token,
         params: { enrollment: { cadence_id: cadence.id } },
         as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body.dig('enrollment', 'status')).to eq('active')

    get cadence_url, headers: agent.create_new_auth_token, as: :json
    expect(response.parsed_body.dig('enrollment', 'cadence', 'id')).to eq(cadence.id)

    delete cadence_url, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:no_content)
    expect(card.kanban_cadence_enrollments.first.reload).to be_canceled
  end
end
