require 'rails_helper'

RSpec.describe 'Kanban opportunity imports', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:board) { create(:kanban_board, account: account) }
  let(:file) { fixture_file_upload(Rails.root.join('spec/assets/oportunidades.csv'), 'text/csv') }

  describe 'POST create' do
    it 'refuses an unauthenticated request' do
      post "/api/v1/accounts/#{account.id}/kanban_boards/#{board.id}/imports"

      expect(response).to have_http_status(:unauthorized)
    end

    it 'refuses an agent who cannot configure the funnel' do
      post "/api/v1/accounts/#{account.id}/kanban_boards/#{board.id}/imports",
           params: { import_file: file }, headers: agent.create_new_auth_token

      expect(response).to have_http_status(:unauthorized)
    end

    it 'asks for a file instead of starting an empty import' do
      post "/api/v1/accounts/#{account.id}/kanban_boards/#{board.id}/imports",
           headers: administrator.create_new_auth_token

      expect(response).to have_http_status(:unprocessable_entity)
      expect(account.data_imports).to be_empty
    end

    it 'keeps the funnel, the fallback stage and the mapping with the import' do
      stage = create(:kanban_stage, account: account, kanban_board: board, name: 'Novo', position: 1)

      post "/api/v1/accounts/#{account.id}/kanban_boards/#{board.id}/imports",
           params: { import_file: file, fallback_stage_id: stage.id, mapping: { 'Vlr' => 'valor_orcado' } },
           headers: administrator.create_new_auth_token

      expect(response).to have_http_status(:created)
      importacao = account.data_imports.last
      expect(importacao.data_type).to eq('kanban_cards')
      expect(importacao.meta).to include('board_id' => board.id, 'fallback_stage_id' => stage.id.to_s)
      expect(importacao.meta['mapping']).to eq('Vlr' => 'valor_orcado')
    end
  end

  describe 'GET show' do
    it 'reports how the import went' do
      importacao = account.data_imports.create!(data_type: 'kanban_cards', meta: { 'board_id' => board.id },
                                                status: :completed, processed_records: 3, total_records: 4)

      get "/api/v1/accounts/#{account.id}/kanban_boards/#{board.id}/imports/#{importacao.id}",
          headers: administrator.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('status' => 'completed', 'processed_records' => 3, 'total_records' => 4)
    end
  end
end
