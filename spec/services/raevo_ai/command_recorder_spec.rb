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

      expect do
        described_class.new(
          integration: integration,
          action_id: 'act-handoff-001',
          command_type: 'handoff.apply',
          payload: { 'reason' => 'operational_failure' }
        ).claim
      end.to raise_error(RaevoAi::CommandRecorder::Conflict)
    end
  end
end
