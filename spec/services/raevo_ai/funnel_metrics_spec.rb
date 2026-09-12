require 'rails_helper'

RSpec.describe RaevoAi::FunnelMetrics do
  let(:account) { create(:account) }
  let(:integration) { RaevoAiIntegration.create!(account: account, clinic_id: 'clinic-anna-alice', enabled: true) }

  def registar_comando(state, action_id, command_type: 'crm.ensure_opportunity', created_at: Time.current)
    integration.raevo_ai_commands.create!(
      action_id: action_id, command_type: command_type,
      payload_digest: Digest::SHA256.hexdigest(action_id), state: state, created_at: created_at
    )
  end

  describe 'oportunidades criadas' do
    it 'conta só os comandos que a secretária chegou a aplicar' do
      registar_comando('applied', 'a1')
      registar_comando('applied', 'a2')
      registar_comando('failed_terminal', 'a3')
      registar_comando('claimed', 'a4')

      expect(described_class.new(integration: integration, window_days: 30).call[:opportunities_created]).to eq(2)
    end

    it 'ignora o que está fora da janela pedida' do
      registar_comando('applied', 'a1')
      registar_comando('applied', 'a2', created_at: 40.days.ago)

      expect(described_class.new(integration: integration, window_days: 30).call[:opportunities_created]).to eq(1)
    end

    it 'não conta outras acções da secretária como oportunidade criada' do
      registar_comando('applied', 'a1')
      registar_comando('applied', 'a2', command_type: 'crm.move_stage')

      expect(described_class.new(integration: integration, window_days: 30).call[:opportunities_created]).to eq(1)
    end
  end
end
