require 'rails_helper'

RSpec.describe RaevoAi::CrmCatalogPublisher do
  let(:account) { create(:account) }
  let(:board) { create(:kanban_board, account: account) }
  let(:incoming) { create(:kanban_stage, account: account, kanban_board: board) }
  let(:qualified) { create(:kanban_stage, account: account, kanban_board: board) }
  let(:proposal) { create(:kanban_stage, account: account, kanban_board: board) }
  let(:integration) do
    RaevoAiIntegration.create!(
      account: account,
      clinic_id: 'clinic-demo',
      enabled: false,
      settings: {
        'crm' => {
          'boards' => {
            'captacao' => {
              'board_id' => board.id,
              'fields' => { 'raevo_ai_status' => { 'field_key' => 'raevo_ai_status' } }
            }
          }
        }
      }
    )
  end

  it 'publishes a validated semantic stage catalog without physical ids in the runtime contract' do
    result = described_class.new(integration: integration).publish!(
      board_key: 'captacao',
      board_id: board.id,
      initial_stage_id: incoming.id,
      stages: {
        'incoming_leads' => { 'stage_id' => incoming.id, 'allowed_from' => ['incoming_leads'] },
        'qualified' => { 'stage_id' => qualified.id, 'allowed_from' => ['incoming_leads'] },
        'price_informed' => { 'stage_id' => proposal.id, 'allowed_from' => %w[incoming_leads qualified] }
      }
    )

    expect(result).to include('board_key' => 'captacao', 'board_id' => board.id)
    expect(integration.reload.settings.dig('crm', 'boards', 'captacao')).to include(
      'initial_stage_id' => incoming.id,
      'stages' => hash_including(
        'qualified' => { 'stage_id' => qualified.id, 'allowed_from' => ['incoming_leads'] },
        'price_informed' => { 'stage_id' => proposal.id, 'allowed_from' => %w[incoming_leads qualified] }
      ),
      'fields' => { 'raevo_ai_status' => { 'field_key' => 'raevo_ai_status' } }
    )
  end

  it 'fails closed when a stage belongs to another board' do
    other_stage = create(:kanban_stage, account: account, kanban_board: create(:kanban_board, account: account))
    original_settings = integration.settings.deep_dup

    expect do
      described_class.new(integration: integration).publish!(
        board_key: 'captacao',
        board_id: board.id,
        initial_stage_id: incoming.id,
        stages: { 'qualified' => { 'stage_id' => other_stage.id, 'allowed_from' => ['incoming_leads'] } }
      )
    end.to raise_error(described_class::InvalidCatalog)

    expect(integration.reload.settings).to eq(original_settings)
  end

  it 'rejects an allowed_from reference that was not published' do
    expect do
      described_class.new(integration: integration).publish!(
        board_key: 'captacao',
        board_id: board.id,
        initial_stage_id: incoming.id,
        stages: { 'qualified' => { 'stage_id' => qualified.id, 'allowed_from' => ['missing'] } }
      )
    end.to raise_error(described_class::InvalidCatalog, /allowed_from/)
  end
end
