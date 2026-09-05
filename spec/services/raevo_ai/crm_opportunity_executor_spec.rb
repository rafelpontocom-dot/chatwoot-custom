require 'rails_helper'

RSpec.describe RaevoAi::CrmOpportunityExecutor do
  let(:account) { create(:account) }
  let(:board) { create(:kanban_board, account: account) }
  let(:initial_stage) { create(:kanban_stage, account: account, kanban_board: board, name: 'New lead') }
  let(:contact) { create(:contact, account: account, name: 'Maria Silva') }
  let(:inbox) { create(:inbox, account: account, name: 'Sales') }
  let(:conversation) { create(:conversation, account: account, contact: contact, inbox: inbox) }
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
              'initial_stage_id' => initial_stage.id,
              'fields' => {}
            }
          }
        }
      }
    )
  end

  def execute(action_id: 'turn-100:opportunity')
    described_class.new(
      integration: integration,
      conversation: conversation,
      command: { action_id: action_id, board_key: 'acquisition' }
    ).perform
  end

  it 'creates a single conversation opportunity in the explicitly published initial stage' do
    result = nil
    expect do
      result = execute
    end.to change(KanbanCard.conversation, :count).by(1)

    card = KanbanCard.conversation.last
    expect(card).to have_attributes(account: account, kanban_board: board, kanban_stage: initial_stage, conversation: conversation)
    expect(result).to eq(
      'action_id' => 'turn-100:opportunity',
      'status' => 'applied',
      'receipts' => { 'opportunity' => { 'status' => 'created' } }
    )
  end

  it 'is idempotent for the same action id' do
    first = execute
    retry_result = nil

    expect { retry_result = execute }.not_to change(KanbanCard.conversation, :count)
    expect(retry_result).to eq(first)
  end

  it 'keeps a pre-existing opportunity and records that it already exists' do
    create(:kanban_card, :conversation_origin, account: account, kanban_board: board, kanban_stage: initial_stage, conversation: conversation)
    result = nil

    expect { result = execute }.not_to change(KanbanCard.conversation, :count)
    expect(result.dig('receipts', 'opportunity', 'status')).to eq('already_exists')
  end
end
