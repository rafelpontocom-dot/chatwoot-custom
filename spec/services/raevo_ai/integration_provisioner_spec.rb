require 'rails_helper'

RSpec.describe RaevoAi::IntegrationProvisioner do
  let(:account) { create(:account) }
  let(:board) { create(:kanban_board, account: account) }
  let(:qualification) { create(:kanban_stage, account: account, kanban_board: board) }
  let(:scheduling) { create(:kanban_stage, account: account, kanban_board: board) }
  let(:scheduled) { create(:kanban_stage, account: account, kanban_board: board) }
  let(:integration) do
    RaevoAiIntegration.create!(account: account, clinic_id: 'clinic-demo', enabled: false)
  end

  it 'publishes the CRM catalog and IA fields without enabling the integration' do
    result = described_class.new(integration: integration, command_token: 'a' * 48).provision!(
      board_key: 'consulta',
      board_id: board.id,
      initial_stage_id: qualification.id,
      stages: {
        'qualified' => { 'stage_id' => qualification.id, 'allowed_from' => ['qualified'] },
        'scheduling_requested' => { 'stage_id' => scheduling.id, 'allowed_from' => ['qualified'] },
        'booking_confirmed' => { 'stage_id' => scheduled.id, 'allowed_from' => ['scheduling_requested'] }
      },
      ai_tab_board_ids: [board.id]
    )

    settings = integration.reload.settings
    expect(result).to include('enabled' => false, 'board_key' => 'consulta', 'board_ids' => [board.id])
    expect(integration).not_to be_enabled
    expect(settings['command_token_digest']).to eq(Digest::SHA256.hexdigest('a' * 48))
    expect(settings.dig('crm', 'boards', 'consulta', 'stages')).to include(
      'booking_confirmed' => { 'stage_id' => scheduled.id, 'allowed_from' => ['scheduling_requested'] }
    )
    expect(settings.dig('opportunity_ai_tab', 'board_ids')).to eq([board.id])
    expect(board.reload.configured_custom_field_definitions.map { |field| field['key'] }).to include('raevo_ai_status')
  end

  it 'fails closed when a command token was not supplied' do
    expect do
      described_class.new(integration: integration, command_token: '').provision!(
        board_key: 'consulta',
        board_id: board.id,
        initial_stage_id: qualification.id,
        stages: { 'qualified' => { 'stage_id' => qualification.id, 'allowed_from' => ['qualified'] } },
        ai_tab_board_ids: [board.id]
      )
    end.to raise_error(described_class::InvalidProvisioning, /command token/)

    expect(integration.reload).not_to be_enabled
    expect(integration.settings).to eq({})
  end

  it 'reconfigures a provisioned inactive catalog without requiring the command token again' do
    described_class.new(integration: integration, command_token: 'a' * 48).provision!(
      board_key: 'consulta',
      board_id: board.id,
      initial_stage_id: qualification.id,
      stages: { 'qualified' => { 'stage_id' => qualification.id, 'allowed_from' => [] } },
      ai_tab_board_ids: [board.id]
    )
    token_digest = integration.reload.settings.fetch('command_token_digest')

    result = described_class.new(integration: integration).reconfigure!(
      board_key: 'consulta',
      board_id: board.id,
      initial_stage_id: scheduling.id,
      stages: { 'qualified' => { 'stage_id' => scheduling.id, 'allowed_from' => [] } },
      ai_tab_board_ids: [board.id]
    )

    settings = integration.reload.settings
    expect(result).to include('enabled' => false, 'board_key' => 'consulta', 'board_ids' => [board.id])
    expect(settings.fetch('command_token_digest')).to eq(token_digest)
    expect(settings.dig('crm', 'catalog_version')).to eq(2)
    expect(settings.dig('crm', 'boards', 'consulta', 'initial_stage_id')).to eq(scheduling.id)
  end

  it 'activates only after the catalog, fields and command token are provisioned' do
    described_class.new(integration: integration, command_token: 'a' * 48).provision!(
      board_key: 'consulta',
      board_id: board.id,
      initial_stage_id: qualification.id,
      stages: { 'qualified' => { 'stage_id' => qualification.id, 'allowed_from' => [] } },
      ai_tab_board_ids: [board.id]
    )

    result = described_class.new(integration: integration, command_token: '').activate!(actor_ref: 'super_admin:1')

    expect(result).to include('enabled' => true, 'clinic_id' => 'clinic-demo')
    expect(integration.reload).to be_enabled
    expect(integration.settings.dig('activation', 'actor_ref')).to eq('super_admin:1')
  end

  it 'refuses activation before provisioning completes' do
    expect do
      described_class.new(integration: integration, command_token: '').activate!(actor_ref: 'super_admin:1')
    end.to raise_error(described_class::InvalidProvisioning, /not provisioned/)

    expect(integration.reload).not_to be_enabled
  end
end
