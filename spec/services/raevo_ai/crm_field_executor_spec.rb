require 'rails_helper'

RSpec.describe RaevoAi::CrmFieldExecutor do
  let(:account) { create(:account) }
  let(:board) do
    create(
      :kanban_board,
      account: account,
      custom_field_definitions: [
        {
          'key' => 'preferred_period', 'label' => 'Preferred period', 'field_type' => 'select', 'options' => %w[morning afternoon evening]
        },
        { 'key' => 'raevo_ai_next_action', 'label' => 'Next action', 'field_type' => 'text' },
        { 'key' => 'raevo_ai_last_action_at', 'label' => 'Last action', 'field_type' => 'datetime' }
      ]
    )
  end
  let(:stage) { create(:kanban_stage, account: account, kanban_board: board) }
  let(:card) { create(:kanban_card, account: account, kanban_board: board, kanban_stage: stage) }
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
              'fields' => {
                'preferred_period' => {
                  'field_key' => 'preferred_period', 'type' => 'select',
                  'values' => %w[morning afternoon evening], 'overwrite' => 'if_empty'
                },
                'raevo_ai_next_action' => {
                  'field_key' => 'raevo_ai_next_action', 'type' => 'text',
                  'values' => [], 'overwrite' => 'always'
                },
                'raevo_ai_last_action_at' => {
                  'field_key' => 'raevo_ai_last_action_at', 'type' => 'datetime',
                  'values' => [], 'overwrite' => 'always'
                }
              }
            }
          }
        }
      }
    )
  end

  it 'fills an empty published field once and returns the persisted receipt on retry' do
    executor = described_class.new(
      integration: integration,
      card: card,
      command: {
        action_id: 'turn-100:field:preferred_period',
        board_key: 'acquisition',
        expected_lock_version: card.lock_version,
        fields: [{ 'key' => 'preferred_period', 'value' => 'afternoon' }]
      }
    )

    first = executor.perform
    retry_result = executor.perform

    expect(card.reload.custom_field_values).to include('preferred_period' => 'afternoon')
    expect(first).to include('status' => 'applied', 'action_id' => 'turn-100:field:preferred_period')
    expect(retry_result).to eq(first)
    expect(RaevoAiCommand.where(action_id: 'turn-100:field:preferred_period').count).to eq(1)
  end

  it 'rejects an outdated lock version without overwriting a human field value' do
    card.update!(custom_field_values: { 'preferred_period' => 'morning' })

    expect do
      described_class.new(
        integration: integration,
        card: card,
        command: {
          action_id: 'turn-101:field:preferred_period',
          board_key: 'acquisition',
          expected_lock_version: card.lock_version - 1,
          fields: [{ 'key' => 'preferred_period', 'value' => 'afternoon' }]
        }
      ).perform
    end.to raise_error(RaevoAi::CrmFieldExecutor::LockConflict)

    expect(card.reload.custom_field_values).to include('preferred_period' => 'morning')
  end

  it 'rejects a structured value for a text field before it can reach the card' do
    expect do
      described_class.new(
        integration: integration,
        card: card,
        command: {
          action_id: 'turn-102:field:next-action',
          board_key: 'acquisition',
          expected_lock_version: card.lock_version,
          fields: [{ 'key' => 'raevo_ai_next_action', 'value' => { 'action' => 'handoff' } }]
        }
      ).perform
    end.to raise_error(described_class::InvalidValue, 'field value must be a string')
  end

  it 'rejects a datetime that is not ISO 8601' do
    expect do
      described_class.new(
        integration: integration,
        card: card,
        command: {
          action_id: 'turn-103:field:last-action-at',
          board_key: 'acquisition',
          expected_lock_version: card.lock_version,
          fields: [{ 'key' => 'raevo_ai_last_action_at', 'value' => 'tomorrow afternoon' }]
        }
      ).perform
    end.to raise_error(described_class::InvalidValue, 'datetime field value must be ISO 8601')
  end
end
