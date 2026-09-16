require 'rails_helper'

RSpec.describe KanbanCalendar::WorkingHoursSheet do
  let(:account) { create(:account) }
  let(:schedule) { account.kanban_calendar_schedules.create!(name: 'Manhãs da Dra. Anna', timezone: 'America/Recife') }
  let(:sheet) { described_class.new(schedule.kanban_calendar_availability_rules) }

  it 'stores several ranges per day and closed or shortened exceptions, and reads them back the same' do
    sheet.replace!(
      weekly: [{ weekday: 3, ranges: [{ from: '14:00', to: '16:00' }, { from: '08:00', to: '12:00' }] }],
      overrides: [{ date: '2026-10-07', closed: true, note: 'Congresso' }, { date: '2026-10-12', ranges: [{ from: '09:00', to: '11:00' }] }]
    )

    expect(sheet.payload).to eq(
      weekly: [{ weekday: 3, ranges: [{ from: '08:00', to: '12:00' }, { from: '14:00', to: '16:00' }] }],
      overrides: [
        { date: '2026-10-07', closed: true, note: 'Congresso' },
        { date: '2026-10-12', closed: false, note: nil, ranges: [{ from: '09:00', to: '11:00' }] }
      ]
    )
  end

  it 'replaces the whole week but keeps one-off blocks with a time' do
    agenda = KanbanCalendarResource.create!(account: account, name: 'Sala 1', resource_type: 'room', timezone: 'America/Sao_Paulo')
    agenda.kanban_calendar_availability_rules.create!(kind: 'block', date: Date.new(2026, 10, 1), starts_at_local: '10:00', ends_at_local: '11:00')

    described_class.new(agenda.kanban_calendar_availability_rules).replace!(weekly: [], overrides: [])

    expect(agenda.kanban_calendar_availability_rules.pluck(:kind)).to eq(['block'])
  end

  it 'leaves the week untouched when a range is invalid' do
    sheet.replace!(weekly: [{ weekday: 1, ranges: [{ from: '08:00', to: '12:00' }] }], overrides: [])

    expect do
      sheet.replace!(weekly: [{ weekday: 1, ranges: [{ from: '12:00', to: '08:00' }] }], overrides: [])
    end.to raise_error(ActiveRecord::RecordInvalid)
    expect(sheet.payload[:weekly]).to eq([{ weekday: 1, ranges: [{ from: '08:00', to: '12:00' }] }])
  end
end
