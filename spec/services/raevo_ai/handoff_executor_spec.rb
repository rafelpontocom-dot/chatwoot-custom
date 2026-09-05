require 'rails_helper'

RSpec.describe RaevoAi::HandoffExecutor do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:integration) do
    RaevoAiIntegration.create!(
      account: account,
      clinic_id: 'clinic-demo',
      enabled: true,
      settings: {
        'handoff' => {
          'team_id' => team.id,
          'allowed_inbox_ids' => [conversation.inbox_id],
          'labels' => ['intervencao-humana']
        }
      }
    )
  end

  it 'applies assignment, additive labels and a single private note for an action' do
    result = execute_handoff

    expect(conversation.reload.team_id).to eq(team.id)
    expect(conversation.label_list).to include('intervencao-humana')
    expect(conversation.messages.where(private: true).last.content).to include('O contato pediu uma pessoa da equipe.')
    expect(result).to include('action_id' => 'act-handoff-001', 'status' => 'applied')
    expect(result.dig('receipts', 'assignment')).to eq('status' => 'applied', 'team_id' => team.id)

    retry_result = execute_handoff

    expect(retry_result).to eq(result)
    expect(conversation.messages.where(private: true).count).to eq(1)
  end

  private

  def execute_handoff
    described_class.new(
      integration: integration,
      conversation: conversation,
      action_id: 'act-handoff-001',
      reason: 'human_requested',
      note: 'O contato pediu uma pessoa da equipe.'
    ).perform
  end
end
