require 'rails_helper'

RSpec.describe 'Raevo home API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:board) { create(:kanban_board, account: account) }
  let(:stage) { create(:kanban_stage, account: account, kanban_board: board) }

  describe 'GET /api/v1/accounts/:account_id/raevo_home' do
    it 'returns open conversations and overdue actions that need attention' do
      conversation = create(:conversation, account: account, status: :open)
      create(
        :kanban_card,
        :conversation_origin,
        account: account,
        kanban_board: board,
        kanban_stage: stage,
        conversation: conversation,
        next_action_at: 2.hours.ago,
        next_action_type: 'follow_up'
      )

      get "/api/v1/accounts/#{account.id}/raevo_home",
          headers: administrator.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['open_conversations']).to include(
        hash_including('display_id' => conversation.display_id)
      )
      expect(response.parsed_body['overdue_actions']).to include(
        hash_including('kanban_board_id' => board.id, 'kanban_card_id' => kind_of(Integer))
      )
    end

    it 'does not expose a card from a board unavailable to the current agent' do
      agent = create(:user, account: account, role: :agent)
      restricted_board = create(
        :kanban_board,
        account: account,
        visibility_mode: 'selected_agents'
      )
      restricted_stage = create(
        :kanban_stage,
        account: account,
        kanban_board: restricted_board
      )
      card = create(
        :kanban_card,
        account: account,
        kanban_board: restricted_board,
        kanban_stage: restricted_stage,
        next_action_at: 1.hour.ago,
        next_action_type: 'follow_up'
      )

      get "/api/v1/accounts/#{account.id}/raevo_home",
          headers: agent.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['overdue_actions']).not_to include(
        hash_including('kanban_card_id' => card.id)
      )
    end
  end
end
