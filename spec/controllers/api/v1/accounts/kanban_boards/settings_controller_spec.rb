require 'rails_helper'

RSpec.describe 'Kanban board settings API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:board) { create(:kanban_board, account: account) }

  describe 'GET /api/v1/accounts/{account.id}/kanban_boards/{board.id}/settings' do
    it 'returns commercial configuration options' do
      board.update!(
        next_action_types: ['Cobrar retorno', 'Enviar link de pagamento'],
        lost_reason_options: ['Preço', 'Sem resposta']
      )

      get settings_url(board), headers: administrator.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include(
        'next_action_types' => ['Cobrar retorno', 'Enviar link de pagamento'],
        'lost_reason_options' => ['Preço', 'Sem resposta']
      )
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/kanban_boards/{board.id}/settings' do
    it 'updates commercial configuration options' do
      patch settings_url(board),
            headers: administrator.create_new_auth_token,
            params: {
              kanban_board: {
                name: board.name,
                next_action_types: ['Enviar proposta', 'Enviar contrato', 'Outro'],
                lost_reason_options: ['Preço', 'Fechou com outro', 'Outro']
              }
            },
            as: :json

      expect(response).to have_http_status(:success)
      expect(board.reload).to have_attributes(
        next_action_types: ['Enviar proposta', 'Enviar contrato', 'Outro'],
        lost_reason_options: ['Preço', 'Fechou com outro', 'Outro']
      )
      expect(response.parsed_body).to include(
        'next_action_types' => ['Enviar proposta', 'Enviar contrato', 'Outro'],
        'lost_reason_options' => ['Preço', 'Fechou com outro', 'Outro']
      )
    end

    it 'normalizes blank and duplicate commercial configuration values' do
      patch settings_url(board),
            headers: administrator.create_new_auth_token,
            params: {
              kanban_board: {
                name: board.name,
                next_action_types: ['Enviar proposta', ' ', 'Enviar proposta'],
                lost_reason_options: ['', 'Preço', 'Preço']
              }
            },
            as: :json

      expect(response).to have_http_status(:success)
      expect(board.reload).to have_attributes(
        next_action_types: ['Enviar proposta'],
        lost_reason_options: ['Preço']
      )
    end

    it 'updates board-specific opportunity field definitions' do
      stage = create(:kanban_stage, account: account, kanban_board: board)

      patch settings_url(board),
            headers: administrator.create_new_auth_token,
            params: {
              kanban_board: {
                name: board.name,
                custom_field_definitions: [
                  {
                    key: 'consulta_realizada',
                    label: 'Consulta realizada?',
                    field_type: 'select',
                    options: %w[Sim Não],
                    layout: { section: 'qualification', position: 1 }
                  },
                  {
                    key: 'valor_total',
                    label: 'Valor total',
                    field_type: 'formula',
                    formula: 'procedimento + exames',
                    required_stage_ids: [stage.id],
                    condition: { field_key: 'consulta_realizada', equals: 'Sim' },
                    layout: { section: 'commercial', position: 2 }
                  }
                ]
              }
            },
            as: :json

      expect(response).to have_http_status(:success)
      definitions = board.reload.custom_field_definitions
      expect(definitions.first).to include(
        'key' => 'consulta_realizada',
        'field_type' => 'select',
        'options' => %w[Sim Não],
        'layout' => { 'section' => 'qualification', 'position' => 1, 'width' => 'full' }
      )
      expect(definitions.second).to include(
        'key' => 'valor_total',
        'field_type' => 'formula',
        'required_stage_ids' => [stage.id],
        'condition' => { 'field_key' => 'consulta_realizada', 'equals' => 'Sim' },
        'formula' => 'procedimento + exames'
      )
      expect(response.parsed_body['custom_field_definitions']).to eq(definitions)
    end

    it 'updates board-specific opportunity tabs' do
      patch settings_url(board),
            headers: administrator.create_new_auth_token,
            params: {
              kanban_board: {
                custom_field_sections: [
                  { key: 'consulta', label: 'Consulta' },
                  { key: 'financeiro', label: 'Financeiro' }
                ]
              }
            },
            as: :json

      expect(response).to have_http_status(:success)
      expect(board.reload.custom_field_sections).to eq(
        [
          { 'key' => 'consulta', 'label' => 'Consulta' },
          { 'key' => 'financeiro', 'label' => 'Financeiro' }
        ]
      )
      expect(response.parsed_body['custom_field_sections']).to eq(board.custom_field_sections)
    end

    it 'updates compact card fields and stale stage thresholds' do
      stage = create(:kanban_stage, account: account, kanban_board: board)

      patch settings_url(board),
            headers: administrator.create_new_auth_token,
            params: {
              kanban_board: {
                compact_card_field_keys: %w[valor origem],
                stale_stage_thresholds: { stage.id.to_s => 4 }
              }
            },
            as: :json

      expect(response).to have_http_status(:success)
      expect(board.reload.compact_card_field_keys).to eq(%w[valor origem])
      expect(board.stale_stage_thresholds).to eq(stage.id.to_s => 4)
      expect(response.parsed_body).to include(
        'compact_card_field_keys' => %w[valor origem],
        'stale_stage_thresholds' => { stage.id.to_s => 4 }
      )
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/kanban_boards/{board.id}/settings/import_existing_conversations' do
    it 'enqueues the import job and returns accepted metadata' do
      create(:kanban_stage, account: account, kanban_board: board)
      create(:conversation, account: account)

      expect do
        post import_url(board),
             headers: administrator.create_new_auth_token,
             params: { ignore_groups: true },
             as: :json
      end.to have_enqueued_job(KanbanCards::ImportExistingConversationsJob).with(account.id, board.id, ignore_groups: true)

      expect(response).to have_http_status(:accepted)
      expect(response.parsed_body).to include(
        'status' => 'accepted',
        'enqueued' => true,
        'estimated_count' => 1
      )
    end

    it 'does not import conversations synchronously' do
      create(:kanban_stage, account: account, kanban_board: board)
      create(:conversation, account: account)

      expect do
        post import_url(board),
             headers: administrator.create_new_auth_token,
             params: { ignore_groups: false },
             as: :json
      end.not_to change(KanbanCard, :count)
    end

    it 'does not allow agents to enqueue imports' do
      post import_url(board),
           headers: agent.create_new_auth_token,
           params: { ignore_groups: false },
           as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(KanbanCards::ImportExistingConversationsJob).not_to have_been_enqueued
    end

    it 'does not allow importing a board from another account' do
      other_board = create(:kanban_board)

      post import_url(other_board),
           headers: administrator.create_new_auth_token,
           params: { ignore_groups: false },
           as: :json

      expect(response).to have_http_status(:not_found)
      expect(KanbanCards::ImportExistingConversationsJob).not_to have_been_enqueued
    end
  end

  def import_url(target_board)
    "/api/v1/accounts/#{account.id}/kanban_boards/#{target_board.id}/settings/import_existing_conversations"
  end

  def settings_url(target_board)
    "/api/v1/accounts/#{account.id}/kanban_boards/#{target_board.id}/settings"
  end
end
