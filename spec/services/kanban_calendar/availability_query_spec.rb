require 'rails_helper'

RSpec.describe KanbanCalendar::AvailabilityQuery do
  let(:account) { create(:account) }
  let(:resource) do
    KanbanCalendarResource.create!(
      account: account,
      name: 'Consultorio 1',
      resource_type: 'room',
      timezone: 'America/Sao_Paulo'
    )
  end
  let(:starts_at) do
    ActiveSupport::TimeZone['America/Sao_Paulo'].parse('2026-08-10 13:00:00')
  end

  it 'keeps an unconfigured resource available for compatibility' do
    query = described_class.new(
      resource: resource,
      starts_at: starts_at,
      ends_at: starts_at + 50.minutes
    )

    expect(query).to be_available
  end

  it 'requires an appointment to fit a configured weekly window' do
    resource.kanban_calendar_availability_rules.create!(
      kind: 'weekly_window',
      weekday: starts_at.wday,
      starts_at_local: '09:00',
      ends_at_local: '12:00'
    )
    query = described_class.new(
      resource: resource,
      starts_at: starts_at,
      ends_at: starts_at + 50.minutes
    )

    expect(query).not_to be_available
  end

  it 'gives a date override priority over the weekly window' do
    resource.kanban_calendar_availability_rules.create!(
      kind: 'weekly_window',
      weekday: starts_at.wday,
      starts_at_local: '09:00',
      ends_at_local: '12:00'
    )
    resource.kanban_calendar_availability_rules.create!(
      kind: 'date_override',
      date: starts_at.to_date,
      starts_at_local: '13:00',
      ends_at_local: '16:00'
    )
    query = described_class.new(
      resource: resource,
      starts_at: starts_at,
      ends_at: starts_at + 50.minutes
    )

    expect(query).to be_available
  end

  it 'blocks an entire date even when the weekly window is open' do
    resource.kanban_calendar_availability_rules.create!(
      kind: 'weekly_window',
      weekday: starts_at.wday,
      starts_at_local: '09:00',
      ends_at_local: '18:00'
    )
    resource.kanban_calendar_availability_rules.create!(
      kind: 'block',
      date: starts_at.to_date
    )

    query = described_class.new(
      resource: resource,
      starts_at: starts_at,
      ends_at: starts_at + 50.minutes
    )

    expect(query).not_to be_available
  end

  it 'blocks only the configured interval on a date' do
    resource.kanban_calendar_availability_rules.create!(
      kind: 'weekly_window',
      weekday: starts_at.wday,
      starts_at_local: '09:00',
      ends_at_local: '18:00'
    )
    resource.kanban_calendar_availability_rules.create!(
      kind: 'block',
      date: starts_at.to_date,
      starts_at_local: '12:00',
      ends_at_local: '14:00'
    )

    blocked_query = described_class.new(
      resource: resource,
      starts_at: starts_at,
      ends_at: starts_at + 50.minutes
    )
    free_query = described_class.new(
      resource: resource,
      starts_at: starts_at.change(hour: 15),
      ends_at: starts_at.change(hour: 15) + 50.minutes
    )

    expect(blocked_query).not_to be_available
    expect(free_query).to be_available
  end
end
