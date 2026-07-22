require 'rails_helper'

RSpec.describe KanbanCardEvent do
  it 'publishes a stable domain event after a commercial change commits' do
    card = create(:kanban_card)
    source_stage_id = card.kanban_stage_id
    next_stage = create(:kanban_stage, account: card.account, kanban_board: card.kanban_board)
    allow(Rails.configuration.dispatcher).to receive(:dispatch)

    card.reorder_to_position!(kanban_stage: next_stage, position: 1)

    event = card.reload.kanban_card_events.find_by!(event_type: 'stage_changed')

    expect(Rails.configuration.dispatcher).to have_received(:dispatch).with(
      Events::Types::KANBAN_CARD_STAGE_CHANGED,
      event.occurred_at,
      hash_including(
        account_id: card.account_id,
        board_id: card.kanban_board_id,
        stage_id: next_stage.id,
        card_id: card.id,
        contact_id: card.contact_id,
        conversation_id: card.conversation_id,
        owner_id: card.owner_id,
        event_id: event.id,
        event_type: 'stage_changed',
        change_set: { 'kanban_stage_id' => [source_stage_id, next_stage.id] }
      )
    )
  end

  it 'does not publish the card-created event twice' do
    allow(Rails.configuration.dispatcher).to receive(:dispatch)

    create(:kanban_card)

    expect(Rails.configuration.dispatcher).not_to have_received(:dispatch).with(
      Events::Types::KANBAN_CARD_CREATED,
      anything,
      anything
    )
  end

  it 'cannot be changed after it is created' do
    event = create(:kanban_card_event)

    expect(event.update(event_type: 'stage_changed')).to be(false)
    expect(event.errors[:base]).to be_present
    expect { event.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)
  end

  it 'validates that the event belongs to the card account and board' do
    event = build(:kanban_card_event)
    event.account = create(:account)

    expect(event).not_to be_valid
    expect(event.errors[:account_id]).to be_present
  end
end
