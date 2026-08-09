require 'rails_helper'

RSpec.describe KanbanCalendarGoogleConnection do
  let(:account) { create(:account) }
  let(:resource) do
    KanbanCalendarResource.create!(
      account: account,
      name: 'Dra. RAEVO',
      resource_type: 'generic',
      timezone: 'America/Sao_Paulo'
    )
  end

  it 'connects one Google calendar to a calendar resource' do
    connection = described_class.new(
      account: account,
      kanban_calendar_resource: resource,
      access_token: 'access-token',
      refresh_token: 'refresh-token',
      expires_at: 1.hour.from_now,
      calendar_id: 'primary',
      status: 'connected'
    )

    expect(connection).to be_valid
  end

  it 'prevents a second connection for the same agenda' do
    described_class.create!(
      account: account,
      kanban_calendar_resource: resource,
      access_token: 'access-token',
      refresh_token: 'refresh-token',
      expires_at: 1.hour.from_now,
      status: 'connected'
    )

    duplicate = described_class.new(
      account: account,
      kanban_calendar_resource: resource,
      access_token: 'other-access-token',
      refresh_token: 'other-refresh-token',
      expires_at: 1.hour.from_now,
      status: 'connected'
    )

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:kanban_calendar_resource_id]).to be_present
  end

  it 'requires credentials while connected' do
    connection = described_class.new(
      account: account,
      kanban_calendar_resource: resource,
      status: 'connected'
    )

    expect(connection).not_to be_valid
    expect(connection.errors[:access_token]).to be_present
    expect(connection.errors[:refresh_token]).to be_present
  end
end
