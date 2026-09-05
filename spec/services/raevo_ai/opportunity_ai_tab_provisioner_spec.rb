require 'rails_helper'

RSpec.describe RaevoAi::OpportunityAiTabProvisioner do
  describe '#configure!' do
    let(:account) { create(:account) }
    let(:board) { create(:kanban_board, account: account) }
    let(:integration) do
      RaevoAiIntegration.create!(
        account: account,
        clinic_id: 'clinic-demo',
        enabled: true,
        settings: {
          'crm' => {
            'boards' => {
              'acquisition' => { 'board_id' => board.id, 'fields' => {} }
            }
          }
        }
      )
    end

    it 'provisions the standard ELIS fields only on a CRM-published board' do
      result = described_class.new(integration: integration).configure!(board_ids: [board.id], enabled: true)

      expect(result).to eq('enabled' => true, 'board_ids' => [board.id])
      expect(board.reload.configured_custom_field_sections).to include(
        hash_including('key' => 'ai', 'label' => 'IA')
      )
      expect(board.configured_custom_field_definitions).to include(
        hash_including('key' => 'raevo_ai_summary', 'field_type' => 'textarea'),
        hash_including('key' => 'raevo_ai_status', 'field_type' => 'select'),
        hash_including('key' => 'raevo_ai_last_action_at', 'field_type' => 'datetime')
      )
      expect(integration.reload.settings.dig('crm', 'boards', 'acquisition', 'fields')).to include(
        'raevo_ai_summary' => hash_including('overwrite' => 'always'),
        'raevo_ai_status' => hash_including('values' => %w[em_atendimento qualificado pre_agendado agendado handoff_humano bloqueado])
      )
    end

    it 'fails closed when enabled without a CRM board selection' do
      expect do
        described_class.new(integration: integration).configure!(enabled: true, board_ids: [])
      end.to raise_error(described_class::InvalidBoard)
    end

    it 'fails closed without changing the board when a standard IA field conflicts with a client field' do
      conflicting_definitions = [
        {
          'key' => 'raevo_ai_status',
          'label' => 'Status comercial do cliente',
          'field_type' => 'select',
          'options' => %w[novo convertido]
        }
      ]
      board.update!(custom_field_definitions: conflicting_definitions)
      original_definitions = board.reload.configured_custom_field_definitions.deep_dup
      original_settings = integration.settings.deep_dup

      expect do
        described_class.new(integration: integration).configure!(board_ids: [board.id], enabled: true)
      end.to raise_error(described_class::InvalidBoard, /incompatible IA field definition/)

      expect(board.reload.configured_custom_field_definitions).to eq(original_definitions)
      expect(integration.reload.settings).to eq(original_settings)
    end

    it 'rolls back board provisioning when integration settings cannot be saved' do
      provisioner = described_class.new(integration: integration)
      original_definitions = board.reload.configured_custom_field_definitions.deep_dup
      allow(provisioner).to receive(:update_integration_settings!).and_raise(ActiveRecord::RecordInvalid.new(integration))

      expect do
        provisioner.configure!(board_ids: [board.id], enabled: true)
      end.to raise_error(ActiveRecord::RecordInvalid)

      expect(board.reload.configured_custom_field_definitions).to eq(original_definitions)
      expect(board.configured_custom_field_sections.map { |section| section['key'] }).not_to include('ai')
    end
  end
end
