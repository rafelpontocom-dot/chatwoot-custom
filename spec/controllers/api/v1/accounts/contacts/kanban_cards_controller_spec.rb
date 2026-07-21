require 'rails_helper'

RSpec.describe 'Contact Kanban Cards API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:contact) { create(:contact, account: account, name: 'Maria Silva') }
  let(:inbox) { create(:inbox, account: account, name: 'Sales Inbox') }
  let(:kanban_board) { create(:kanban_board, account: account, name: 'Sales', position: 1) }
  let(:stage) { create(:kanban_stage, account: account, kanban_board: kanban_board, name: 'New', color: 'blue', position: 1) }

  before do
    create(:inbox_member, user: agent, inbox: inbox)
  end

  describe 'GET /api/v1/accounts/{account.id}/contacts/{contact.id}/kanban_cards' do
    it 'returns unauthorized for unauthenticated users' do
      get contact_kanban_cards_url

      expect(response).to have_http_status(:unauthorized)
    end

    it 'lists active linked cards for the contact' do
      manual_card = create(:kanban_card, account: account, kanban_board: kanban_board, kanban_stage: stage,
                                         contact: contact, inbox: inbox, subject: 'Implante dentário')
      conversation = create(:conversation, account: account, contact: contact, inbox: inbox)
      conversation_card = create(:kanban_card, :conversation_origin, account: account, kanban_board: kanban_board,
                                                                     kanban_stage: stage, conversation: conversation)

      get contact_kanban_cards_url, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['payload']).to contain_exactly(
        hash_including(
          'id' => manual_card.id,
          'subject' => 'Implante dentário',
          'conversation_id' => nil,
          'kanban_board' => { 'id' => kanban_board.id, 'name' => 'Sales' },
          'kanban_stage' => { 'id' => stage.id, 'name' => 'New', 'color' => 'blue' }
        ),
        hash_including(
          'id' => conversation_card.id,
          'conversation_id' => conversation.display_id
        )
      )
    end

    it 'excludes cards for other contacts' do
      create(:kanban_card, account: account, kanban_board: kanban_board, kanban_stage: stage,
                           contact: create(:contact, account: account), inbox: inbox)

      get contact_kanban_cards_url, headers: agent.create_new_auth_token, as: :json

      expect(response.parsed_body['payload']).to be_empty
    end

    it 'omits selected agent boards when the agent is not a member' do
      create(:kanban_card, account: account, kanban_board: kanban_board, kanban_stage: stage,
                           contact: contact, inbox: inbox)
      kanban_board.update!(visibility_mode: 'selected_agents')

      get contact_kanban_cards_url, headers: agent.create_new_auth_token, as: :json

      expect(response.parsed_body['payload']).to be_empty
    end

    it 'keeps selected agent boards for administrators' do
      create(:kanban_card, account: account, kanban_board: kanban_board, kanban_stage: stage,
                           contact: contact, inbox: inbox)
      kanban_board.update!(visibility_mode: 'selected_agents')

      get contact_kanban_cards_url, headers: administrator.create_new_auth_token, as: :json

      expect(response.parsed_body['payload']).to be_present
    end
  end

  def contact_kanban_cards_url
    "/api/v1/accounts/#{account.id}/contacts/#{contact.id}/kanban_cards"
  end
end
