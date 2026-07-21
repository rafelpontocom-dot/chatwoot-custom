require 'rails_helper'

RSpec.describe KanbanCardEvent do
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
