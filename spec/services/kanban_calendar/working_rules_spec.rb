require 'rails_helper'

RSpec.describe KanbanCalendar::WorkingRules do
  let(:account) { create(:account) }
  let(:agenda) { KanbanCalendarResource.create!(account: account, name: 'Dra. Anna', resource_type: 'user', timezone: 'America/Sao_Paulo') }
  let(:procedure) { KanbanCalendarProcedure.create!(account: account, name: 'Avaliação', duration_minutes: 50) }
  let(:comercial) { account.kanban_calendar_schedules.create!(name: 'Comercial', timezone: 'America/Recife') }
  let(:date) { Date.new(2026, 9, 23) }

  before do
    comercial.kanban_calendar_availability_rules.create!(kind: 'weekly_window', weekday: date.wday, starts_at_local: '09:00', ends_at_local: '12:00')
  end

  it 'uses the agenda own week when the agenda has no named schedule' do
    rules = described_class.new(resource: agenda).rules

    expect(rules.map { |rule| [rule.weekday, rule.starts_at_local.strftime('%H:%M')] }).to include([date.wday, '08:00'])
    expect(described_class.new(resource: agenda).timezone).to eq('America/Sao_Paulo')
  end

  it 'uses the named schedule and its timezone, keeping the agenda one-off blocks' do
    agenda.kanban_calendar_availability_rules.create!(kind: 'block', date: date, starts_at_local: '10:00', ends_at_local: '11:00')
    agenda.update!(kanban_calendar_schedule: comercial)

    rules = described_class.new(resource: agenda.reload).rules

    expect(rules.map(&:kind)).to contain_exactly('weekly_window', 'block')
    expect(described_class.new(resource: agenda).timezone).to eq('America/Recife')
  end

  it 'uses the procedure own schedule over the agenda when the procedure asks for it' do
    manhas = account.kanban_calendar_schedules.create!(name: 'Só do laser', timezone: 'America/Sao_Paulo', kanban_calendar_procedure: procedure)
    manhas.kanban_calendar_availability_rules.create!(kind: 'weekly_window', weekday: date.wday, starts_at_local: '07:00', ends_at_local: '08:00')
    procedure.update!(availability_mode: 'schedule', kanban_calendar_schedule: manhas)

    rules = described_class.new(resource: agenda, procedure: procedure).rules

    expect(rules.map { |rule| rule.starts_at_local.strftime('%H:%M') }).to eq(['07:00'])
  end

  it 'makes a changed named schedule change every agenda that uses it' do
    sala = KanbanCalendarResource.create!(account: account, name: 'Sala 1', resource_type: 'room', timezone: 'America/Sao_Paulo')
    [agenda, sala].each { |resource| resource.update!(kanban_calendar_schedule: comercial) }
    KanbanCalendar::WorkingHoursSheet.new(comercial.kanban_calendar_availability_rules)
                                     .replace!(weekly: [{ weekday: date.wday, ranges: [{ from: '14:00', to: '18:00' }] }], overrides: [])

    starts = [agenda, sala].map do |resource|
      described_class.new(resource: resource.reload).rules.map do |rule|
        rule.starts_at_local.strftime('%H:%M')
      end
    end

    expect(starts).to eq([['14:00'], ['14:00']])
  end
end
