require 'rails_helper'

RSpec.describe RaevoAi::CrmStageExecutor do
  let(:account) { create(:account) }
  let(:board) { create(:kanban_board, account: account) }
  let(:new_lead) { create(:kanban_stage, account: account, kanban_board: board, name: 'New lead') }
  let(:scheduling) { create(:kanban_stage, account: account, kanban_board: board, name: 'Scheduling') }
  let(:card) { create(:kanban_card, account: account, kanban_board: board, kanban_stage: new_lead) }
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
              }
            }
          }
        }
      }
    )
  end

  it 'moves the configured card through an allowed semantic event once' do
    executor = described_class.new(
      integration: integration,
      card: card,
      command: {
        action_id: 'turn-100:stage:scheduling_requested',
        board_key: 'acquisition',
        event_key: 'scheduling_requested',
        expected_lock_version: card.lock_version
      }
    )

    first = executor.perform
    retry_result = executor.perform

    expect(card.reload.kanban_stage_id).to eq(scheduling.id)
    expect(first).to include('status' => 'applied', 'action_id' => 'turn-100:stage:scheduling_requested')
    expect(retry_result).to eq(first)
    expect(card.kanban_card_events.where(event_type: 'stage_changed').count).to eq(1)
  end

  it 'rejects an outdated lock version before changing the stage' do
    card.update!(description: 'human edit')

    expect do
      described_class.new(
        integration: integration,
        card: card,
        command: {
          action_id: 'turn-101:stage:scheduling_requested',
          board_key: 'acquisition',
          event_key: 'scheduling_requested',
          expected_lock_version: card.lock_version - 1
        }
      ).perform
    end.to raise_error(RaevoAi::CrmStageExecutor::LockConflict)

    expect(card.reload.kanban_stage_id).to eq(new_lead.id)
  end
end
