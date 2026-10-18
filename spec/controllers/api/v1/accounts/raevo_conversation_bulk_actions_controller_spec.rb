require 'rails_helper'

# RAEVO (17/10, 123jpnbcxh4): ações em massa nas Conversas, também sobre o filtro inteiro.
RSpec.describe 'Api::V1::Accounts::RaevoConversationBulkActionsController', type: :request do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:other_inbox) { create(:inbox, account: account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:url) { "/api/v1/accounts/#{account.id}/raevo_conversation_bulk_actions" }

  before { create(:inbox_member, inbox: inbox, user: agent) }

  describe 'POST count' do
    # A lista pagina de 25 em 25; «as N do filtro» tem de as contar todas.
    it 'counts every conversation of the filter, beyond the first page' do
      create_list(:conversation, 30, account: account, inbox: inbox, status: :open)
      create(:conversation, account: account, inbox: inbox, status: :resolved)

      post "#{url}/count", headers: admin.create_new_auth_token,
                           params: { scope: { filters: { status: 'open', assignee_type: 'all' } } }, as: :json

      expect(response.parsed_body['count']).to eq(30)
    end

    # O filtro avançado e as pastas guardadas chegam como `query`.
    it 'counts every conversation of an advanced filter' do
      create_list(:conversation, 27, account: account, inbox: inbox, status: :pending)
      create(:conversation, account: account, inbox: inbox, status: :open)
      query = [{ attribute_key: 'status', filter_operator: 'equal_to', values: ['pending'], query_operator: nil }]

      post "#{url}/count", headers: admin.create_new_auth_token, params: { scope: { query: query } }, as: :json

      expect(response.parsed_body['count']).to eq(27)
    end

    it 'counts only what the agent is allowed to see' do
      mine = create(:conversation, account: account, inbox: inbox)
      hidden = create(:conversation, account: account, inbox: other_inbox)

      post "#{url}/count", headers: agent.create_new_auth_token,
                           params: { scope: { ids: [mine.display_id, hidden.display_id] } }, as: :json

      expect(response.parsed_body['count']).to eq(1)
    end
  end

  describe 'POST create' do
    let!(:conversations) { create_list(:conversation, 2, account: account, inbox: inbox, status: :open) }
    let(:ids) { conversations.map(&:display_id) }

    it 'queues the action for the selected conversations' do
      expect do
        post url, headers: agent.create_new_auth_token,
                  params: { scope: { ids: ids }, operation: 'pending' }, as: :json
      end.to have_enqueued_job(Raevo::ConversationBulkActionJob).with(account, agent, match_array(ids), 'pending', nil)

      expect(response).to have_http_status(:accepted)
      expect(response.parsed_body).to include('count' => 2, 'skipped' => 0)
    end

    it 'leaves out conversations missing required attributes when resolving, and says how many' do
      account.enable_features!('conversation_required_attributes')
      account.update!(settings: account.settings.to_h.merge('conversation_required_attributes' => ['procedimento']))
      conversations.first.update!(custom_attributes: { 'procedimento' => 'Botox' })

      post url, headers: agent.create_new_auth_token, params: { scope: { ids: ids }, operation: 'resolve' }, as: :json

      expect(response.parsed_body).to include('count' => 1, 'skipped' => 1)
    end

    it 'refuses an unknown operation' do
      post url, headers: agent.create_new_auth_token, params: { scope: { ids: ids }, operation: 'explode' }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    # Decisão do Pedro (17/10): excluir em lote é só para administradores.
    it 'lets only administrators delete in bulk' do
      post url, headers: agent.create_new_auth_token, params: { scope: { ids: ids }, operation: 'delete' }, as: :json
      expect(response).to have_http_status(:unauthorized)

      post url, headers: admin.create_new_auth_token, params: { scope: { ids: ids }, operation: 'delete' }, as: :json
      expect(response).to have_http_status(:accepted)
    end
  end
end
