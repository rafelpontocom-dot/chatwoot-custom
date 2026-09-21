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

    it 'carries the last message so the row says what the person wrote' do
      conversation = create(:conversation, account: account, status: :open)
      create(:message, account: account, conversation: conversation,
                       message_type: :incoming, content: 'Bom dia, consigo remarcar?')

      get "/api/v1/accounts/#{account.id}/raevo_home",
          headers: administrator.create_new_auth_token,
          as: :json

      row = response.parsed_body['open_conversations'].find do |item|
        item['display_id'] == conversation.display_id
      end

      expect(row['last_message']).to eq('Bom dia, consigo remarcar?')
    end

    it 'puts whoever the clinic owes an answer to first, by waiting_since' do
      recent = create(:conversation, account: account, status: :open)
      stale = create(:conversation, account: account, status: :open)
      # last_activity_at não serve: mexe quando somos nós a responder. Aqui a
      # conversa «recente» foi a que esperou menos tempo por resposta nossa.
      recent.update!(waiting_since: 5.minutes.ago, last_activity_at: 6.hours.ago)
      stale.update!(waiting_since: 6.hours.ago, last_activity_at: 5.minutes.ago)

      get "/api/v1/accounts/#{account.id}/raevo_home",
          headers: administrator.create_new_auth_token,
          as: :json

      ids = response.parsed_body['open_conversations'].map { |item| item['display_id'] }

      expect(ids.index(stale.display_id)).to be < ids.index(recent.display_id)
    end

    it 'counts every overdue action, not only the ones that fit in the list' do
      stub_const('Api::V1::Accounts::RaevoHomeController::MAX_ITEMS', 2)
      3.times do |index|
        create(
          :kanban_card,
          :conversation_origin,
          account: account,
          kanban_board: board,
          kanban_stage: stage,
          conversation: create(:conversation, account: account, status: :open),
          next_action_at: (index + 1).hours.ago,
          next_action_type: 'follow_up'
        )
      end

      get "/api/v1/accounts/#{account.id}/raevo_home",
          headers: administrator.create_new_auth_token,
          as: :json

      expect(response.parsed_body['overdue_actions'].size).to eq(2)
      expect(response.parsed_body['overdue_actions_count']).to eq(3)
      expect(response.parsed_body['overdue_actions_count_capped']).to be(false)
    end

    # O contrato dos três cartões: nil é «módulo não está em uso, não mostrar o
    # cartão»; lista vazia é «está ligado e hoje não há nada».
    it 'hides the charges card when Finance is not enabled for the account' do
      get "/api/v1/accounts/#{account.id}/raevo_home",
          headers: administrator.create_new_auth_token,
          as: :json

      expect(response.parsed_body).to have_key('overdue_payments')
      expect(response.parsed_body['overdue_payments']).to be_nil
    end

    it 'always answers with the schedule and the stalled opportunities' do
      get "/api/v1/accounts/#{account.id}/raevo_home",
          headers: administrator.create_new_auth_token,
          as: :json

      expect(response.parsed_body['today_appointments']).to include('count' => 0, 'items' => [])
      expect(response.parsed_body['stale_opportunities']).to include('count' => 0, 'items' => [])
    end

    it 'filters by inbox and can put the newest conversation first' do
      other_inbox = create(:inbox, account: account)
      waiting = create(:conversation, account: account, status: :open, last_activity_at: 3.hours.ago)
      recent = create(:conversation, account: account, inbox: waiting.inbox, status: :open, last_activity_at: 5.minutes.ago)
      create(:conversation, account: account, inbox: other_inbox, status: :open, last_activity_at: 1.hour.ago)

      get "/api/v1/accounts/#{account.id}/raevo_home",
          params: { inbox_id: waiting.inbox_id, conversation_sort: 'recent' },
          headers: administrator.create_new_auth_token,
          as: :json

      display_ids = response.parsed_body['open_conversations'].pluck('display_id')
      expect(display_ids).to eq([recent.display_id, waiting.display_id])
      expect(response.parsed_body['filters']).to include('conversation_sort' => 'recent', 'inbox_id' => waiting.inbox_id)
    end

    it 'filters the overdue actions by funnel and offers the funnels to choose from' do
      other_board = create(:kanban_board, account: account)
      other_stage = create(:kanban_stage, account: account, kanban_board: other_board)
      create(:kanban_card, account: account, kanban_board: board, kanban_stage: stage,
                           next_action_at: 2.hours.ago, next_action_type: 'follow_up')
      create(:kanban_card, account: account, kanban_board: other_board, kanban_stage: other_stage,
                           next_action_at: 3.hours.ago, next_action_type: 'follow_up')

      get "/api/v1/accounts/#{account.id}/raevo_home",
          params: { board_id: board.id },
          headers: administrator.create_new_auth_token,
          as: :json

      expect(response.parsed_body['overdue_actions'].pluck('kanban_board_id').uniq).to eq([board.id])
      expect(response.parsed_body['filters']['boards'].pluck('id')).to include(board.id, other_board.id)
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
