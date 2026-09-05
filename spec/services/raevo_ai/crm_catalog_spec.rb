require 'rails_helper'

RSpec.describe RaevoAi::CrmCatalog do
  let(:account) { create(:account) }
  let(:board) do
    create(
      :kanban_board,
      account: account,
      custom_field_definitions: [
        {
          'key' => 'preferred_period',
          'label' => 'Preferred period',
          'field_type' => 'select',
          'options' => %w[morning afternoon evening]
        }
      ]
    )
  end
  let(:new_lead) { create(:kanban_stage, account: account, kanban_board: board, name: 'New lead') }
  let(:scheduling) { create(:kanban_stage, account: account, kanban_board: board, name: 'Scheduling') }
  let(:integration) do
    RaevoAiIntegration.create!(
      account: account,
      clinic_id: 'clinic-demo',
      enabled: true,
      settings: {
        'crm' => {
          'boards' => {
            'acquisition' => {
              'board_id' => board.id,
              'stages' => {
                'new_lead' => { 'stage_id' => new_lead.id, 'allowed_from' => [] },
                'scheduling_requested' => { 'stage_id' => scheduling.id, 'allowed_from' => ['new_lead'] }
              },
              'fields' => {
                'preferred_period' => {
                  'field_key' => 'preferred_period',
                  'type' => 'select',
                  'values' => %w[morning afternoon evening],
                  'overwrite' => 'if_empty'
                }
              }
            }
          }
        }
      }
    )
  end

  it 'resolves only the configured board, field and allowed semantic stage transition' do
    catalog = described_class.new(integration: integration)

    expect(catalog.resolve_board!('acquisition')).to eq(board)
    expect(catalog.resolve_field!('acquisition', 'preferred_period')).to include(
      key: 'preferred_period', type: 'select', values: %w[morning afternoon evening], overwrite: 'if_empty'
    )
    expect(catalog.resolve_stage!('acquisition', 'scheduling_requested', current_stage_id: new_lead.id)).to eq(scheduling)
  end

  it 'rejects a configured board from another account' do
    integration.settings['crm']['boards']['acquisition']['board_id'] = create(:kanban_board).id
    integration.save!

    expect do
      described_class.new(integration: integration).resolve_board!('acquisition')
    end.to raise_error(RaevoAi::CrmCatalog::InvalidCatalog, 'configured board is not active in the integration account')
  end

  it 'rejects a transition not allowed from the card current stage' do
    expect do
      described_class.new(integration: integration).resolve_stage!(
        'acquisition', 'scheduling_requested', current_stage_id: scheduling.id
      )
    end.to raise_error(RaevoAi::CrmCatalog::TransitionNotAllowed)
  end

  it 'rejects a published select field whose enum does not match the board' do
    definitions = [
      {
        'key' => 'preferred_period',
        'label' => 'Preferred period',
        'field_type' => 'select',
        'options' => %w[morning evening]
      }
    ]
    board.update!(custom_field_definitions: definitions)

    expect do
      described_class.new(integration: integration).resolve_field!('acquisition', 'preferred_period')
    end.to raise_error(RaevoAi::CrmCatalog::InvalidCatalog, 'configured select field values do not match the board')
  end

  it 'rejects a field with an unpublished overwrite policy' do
    integration.settings['crm']['boards']['acquisition']['fields']['preferred_period']['overwrite'] = 'replace_if_old'
    integration.save!

    expect do
      described_class.new(integration: integration).resolve_field!('acquisition', 'preferred_period')
    end.to raise_error(RaevoAi::CrmCatalog::InvalidCatalog, 'configured field overwrite policy is invalid')
  end
end
