require 'rails_helper'

RSpec.describe 'Raevo AI CRM catalog API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:board) do
    create(
      :kanban_board,
      account: account,
      custom_field_definitions: [
        { 'key' => 'valor_da_consulta', 'label' => 'Valor da consulta', 'field_type' => 'currency', 'options' => [] }
      ]
    )
  end
  let(:incoming) { create(:kanban_stage, account: account, kanban_board: board) }
  let(:proposal) { create(:kanban_stage, account: account, kanban_board: board) }
  let(:integration) do
    RaevoAiIntegration.create!(
      account: account,
      clinic_id: 'clinic-demo',
      enabled: true,
      settings: {
        'crm' => {
          'boards' => {
            'captacao' => {
              'board_id' => board.id,
              'initial_stage_id' => incoming.id,
              'fields' => {},
              'stages' => { 'incoming_leads' => { 'stage_id' => incoming.id, 'allowed_from' => ['incoming_leads'] } }
            }
          }
        }
      }
    )
  end
  let(:path) { "/api/v1/accounts/#{account.id}/raevo_ai/crm_catalog" }

  it 'lets an administrator publish additive validated entries while the integration is active' do
    integration

    patch path,
          params: {
            board_key: 'captacao',
            fields: { valor_da_consulta: { type: 'currency', overwrite: 'always' } },
            stages: { price_informed: { stage_id: proposal.id, allowed_from: ['incoming_leads'] } }
          },
          headers: administrator.create_new_auth_token,
          as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include('board_key' => 'captacao', 'fields' => ['valor_da_consulta'], 'events' => ['price_informed'])
  end
end
