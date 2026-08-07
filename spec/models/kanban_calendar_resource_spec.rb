require 'rails_helper'

RSpec.describe KanbanCalendarResource do
  it 'requires a user when the resource represents a professional' do
    resource = described_class.new(
      account: create(:account),
      name: 'Dra. Ana',
      resource_type: 'user',
      timezone: 'America/Sao_Paulo'
    )

    expect(resource).not_to be_valid
    expect(resource.errors[:user]).to be_present
  end

  it 'accepts a room with one appointment capacity' do
    resource = described_class.new(
      account: create(:account),
      name: 'Consultório 1',
      resource_type: 'room',
      timezone: 'America/Sao_Paulo',
      capacity: 1
    )

    expect(resource).to be_valid
  end
end
