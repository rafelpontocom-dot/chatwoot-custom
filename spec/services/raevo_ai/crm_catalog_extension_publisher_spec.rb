require 'rails_helper'

RSpec.describe RaevoAi::CrmCatalogExtensionPublisher do
  let(:account) { create(:account) }
  let(:board) { create(:kanban_board, account: account) }
  let(:incoming) { create(:kanban_stage, account: account, kanban_board: board) }
  let(:qualified) { create(:kanban_stage, account: account, kanban_board: board) }
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
              'stages' => {
                'incoming_leads' => { 'stage_id' => incoming.id, 'allowed_from' => ['incoming_leads'] },
                'qualified' => { 'stage_id' => qualified.id, 'allowed_from' => ['incoming_leads'] }
              }
            }
          }
        }
      }
    )
  end

  before do
    field_definitions = [
      {
        'key' => 'valor_da_consulta', 'label' => 'Valor da consulta',
        'field_type' => 'currency', 'options' => []
      }
    ]
    board.update!(custom_field_definitions: field_definitions)
  end

  it 'adds validated field and semantic stage entries without changing published entries' do
    result = described_class.new(integration: integration).publish!(
      board_key: 'captacao',
      fields: { 'valor_da_consulta' => { 'type' => 'currency', 'overwrite' => 'always' } },
      stages: { 'price_informed' => { 'stage_id' => proposal.id, 'allowed_from' => %w[incoming_leads qualified] } }
    )

    expect(result).to eq('board_key' => 'captacao', 'fields' => ['valor_da_consulta'], 'events' => ['price_informed'])
    expect(integration.reload.settings.dig('crm', 'boards', 'captacao')).to include(
      'fields' => { 'valor_da_consulta' => { 'field_key' => 'valor_da_consulta', 'type' => 'currency', 'values' => [], 'overwrite' => 'always' } },
      'stages' => hash_including(
        'incoming_leads' => { 'stage_id' => incoming.id, 'allowed_from' => ['incoming_leads'] },
        'price_informed' => { 'stage_id' => proposal.id, 'allowed_from' => %w[incoming_leads qualified] }
      )
    )
  end

  it 'rejects a request that changes an existing published field' do
    published_field = {
      'field_key' => 'valor_da_consulta', 'type' => 'currency',
      'values' => [], 'overwrite' => 'if_empty'
    }
    settings = integration.settings.deep_merge(
      'crm' => { 'boards' => { 'captacao' => { 'fields' => { 'valor_da_consulta' => published_field } } } }
    )
    integration.update!(settings: settings)

    expect do
      described_class.new(integration: integration).publish!(
        board_key: 'captacao',
        fields: { 'valor_da_consulta' => { 'type' => 'currency', 'overwrite' => 'always' } },
        stages: {}
      )
    end.to raise_error(described_class::InvalidCatalog, /already published/)
  end
end
