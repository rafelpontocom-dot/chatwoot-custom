require 'rails_helper'

RSpec.describe RaevoAi::CommandRecorder do
  let(:integration) { RaevoAiIntegration.create!(account: create(:account), clinic_id: 'clinic-demo', enabled: true) }
  let(:payload) { { 'reason' => 'human_requested', 'summary' => { 'name' => 'Ana' } } }

  describe '#claim' do
    it 'claims an action once and returns the existing claim for an identical retry' do
      first_claim = described_class.new(
        integration: integration,
        action_id: 'act-handoff-001',
        command_type: 'handoff.apply',
        payload: payload
      ).claim

      retry_claim = described_class.new(
        integration: integration,
        action_id: 'act-handoff-001',
        command_type: 'handoff.apply',
        payload: { 'summary' => { 'name' => 'Ana' }, 'reason' => 'human_requested' }
      ).claim

      expect(first_claim.created).to be(true)
      expect(first_claim.command.state).to eq('claimed')
      expect(retry_claim.created).to be(false)
      expect(retry_claim.command.id).to eq(first_claim.command.id)
    end

    it 'rejects reuse of an action id with a different command payload' do
      described_class.new(
        integration: integration,
        action_id: 'act-handoff-001',
        command_type: 'handoff.apply',
        payload: payload
      ).claim

      # Compara pelo NOME da classe, não pela constante: em teste o Rails recarrega
      # código (`cache_classes = false`), e a constante que o `described_class` fechou
      # ao carregar o ficheiro pode já não ser a que o matcher resolve na execução —
      # mesmo nome, objeto diferente, e a comparação por identidade falha.
      erro = begin
        described_class.new(
          integration: integration,
          action_id: 'act-handoff-001',
          command_type: 'handoff.apply',
          payload: { 'reason' => 'operational_failure' }
        ).claim
        nil
      rescue StandardError => e
        e
      end

      expect(erro.class.name).to eq('RaevoAi::CommandRecorder::Conflict')
      expect(erro.message).to eq('action_id was already claimed with a different command')
    end
  end
end
