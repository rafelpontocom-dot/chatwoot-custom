require 'rails_helper'

RSpec.describe RaevoAi::CrmCardResolver do
  let(:account) { create(:account) }
  let(:board) { create(:kanban_board, account: account) }
  let(:stage) { create(:kanban_stage, account: account, kanban_board: board) }
  let(:contact) { create(:contact, account: account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, contact: contact, inbox: inbox) }
  let(:integration) { RaevoAiIntegration.create!(account: account, clinic_id: 'clinic-demo', enabled: true) }

  it 'resolves the single open board opportunity of the conversation contact' do
    landing_card = create(
      :kanban_card,
      account: account,
      contact: contact,
      inbox: inbox,
      kanban_board: board,
      kanban_stage: stage,
      origin: 'manual'
    )

    card = described_class.new(integration: integration, conversation: conversation, board: board).resolve!

    expect(card).to eq(landing_card)
  end

  it 'does not choose between multiple open board opportunities of the same contact' do
    2.times do |index|
      create(
        :kanban_card,
        account: account,
        contact: contact,
        inbox: inbox,
        kanban_board: board,
        kanban_stage: stage,
        origin: 'manual',
        subject: "Landing #{index}"
      )
    end

    expect do
      described_class.new(integration: integration, conversation: conversation, board: board).resolve!
    end.to raise_error(described_class::AmbiguousCard)
  end
end
