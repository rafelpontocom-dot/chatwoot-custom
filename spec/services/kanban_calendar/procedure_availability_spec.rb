require 'rails_helper'

RSpec.describe KanbanCalendar::ProcedureAvailability do
  let(:account) { create(:account) }
  let(:timezone) { 'America/Sao_Paulo' }
  let(:date) { Date.new(2026, 9, 23) }
  let(:anna) { KanbanCalendarResource.create!(account: account, name: 'Dra. Anna', resource_type: 'user', timezone: timezone) }
  let(:bruno) { KanbanCalendarResource.create!(account: account, name: 'Dr. Bruno', resource_type: 'user', timezone: timezone) }
  let(:sala) { KanbanCalendarResource.create!(account: account, name: 'Sala 1', resource_type: 'room', timezone: timezone) }
  let(:procedure) do
    KanbanCalendarProcedure.create!(account: account, name: 'Avaliação', duration_minutes: 60, slot_interval_minutes: 60,
                                    kanban_calendar_resources: [anna, bruno, sala])
  end
  let(:now) { ActiveSupport::TimeZone[timezone].local(2026, 9, 20, 8) }

  def local(hour)
    ActiveSupport::TimeZone[timezone].local(date.year, date.month, date.day, hour)
  end

  def book(resources, hour)
    KanbanCalendar::BookAppointmentService.new(
      account: account, contact: create(:contact, account: account), procedure: procedure,
      resource_ids: resources.map(&:id), starts_at: local(hour), timezone: timezone
    ).perform!
  end

  def hours(slots)
    slots.map { |slot| [slot[:starts_at].in_time_zone(timezone).hour, slot[:resources].map(&:name)] }
  end

  before do
    [anna, bruno, sala].each do |resource|
      resource.kanban_calendar_availability_rules.delete_all
      resource.kanban_calendar_availability_rules.create!(kind: 'weekly_window', weekday: date.wday, starts_at_local: '09:00', ends_at_local: '12:00')
    end
  end

  it 'offers a time while any eligible professional and a room are free, and names who takes it' do
    book([anna, sala], 9)
    book([bruno], 10)

    expect(hours(described_class.new(procedure: procedure).slots(date: date))).to eq(
      [[10, ['Dra. Anna', 'Sala 1']], [11, ['Dr. Bruno', 'Sala 1']]]
    )
  end

  it 'only offers the chosen professional when the patient picks one' do
    book([bruno], 11)

    slots = described_class.new(procedure: procedure, professional_id: bruno.id).slots(date: date)

    expect(hours(slots)).to eq([[9, ['Dr. Bruno', 'Sala 1']], [10, ['Dr. Bruno', 'Sala 1']]])
  end

  it 'puts first in the round robin the team member who got an appointment longest ago' do
    team = account.kanban_calendar_teams.create!(name: 'Dermatologia', assignment_strategy: 'round_robin')
    team.kanban_calendar_team_members.create!(kanban_calendar_resource: anna, last_assigned_at: 1.hour.ago)
    team.kanban_calendar_team_members.create!(kanban_calendar_resource: bruno, last_assigned_at: 2.days.ago)
    procedure.update!(assignment_strategy: 'round_robin', kanban_calendar_team: team)

    expect(described_class.new(procedure: procedure).slots(date: date).first[:resources].map(&:name)).to eq(['Dr. Bruno', 'Sala 1'])
  end

  it 'needs every team member free at once when the team works together' do
    team = account.kanban_calendar_teams.create!(name: 'Cirurgia', assignment_strategy: 'collective')
    [anna, bruno].each { |resource| team.kanban_calendar_team_members.create!(kanban_calendar_resource: resource) }
    procedure.update!(assignment_strategy: 'collective', kanban_calendar_team: team)
    book([bruno], 10)

    expect(hours(described_class.new(procedure: procedure).slots(date: date)).map(&:first)).to eq([9, 11])
  end

  it 'keeps the procedure notice and future window for patients booking by themselves' do
    procedure.update!(minimum_notice_minutes: (3 * 24 * 60) + 61)

    patient = described_class.new(procedure: procedure, patient: true, now: now).slots(date: date)
    staff = described_class.new(procedure: procedure, now: now).slots(date: date)

    expect(hours(patient).map(&:first)).to eq([10, 11])
    expect(hours(staff).map(&:first)).to eq([9, 10, 11])
  end

  it 'stops offering the day to patients once the daily limit is reached' do
    procedure.update!(daily_limit: 1)
    book([anna, sala], 9)

    expect(described_class.new(procedure: procedure, patient: true, now: now).slots(date: date)).to be_empty
  end

  it 'lists only the days of the month that have room' do
    day_after = date + 1
    [anna, bruno, sala].each do |resource|
      resource.kanban_calendar_availability_rules.create!(kind: 'block', date: date)
    end

    days = described_class.new(procedure: procedure).days_with_slots(from: date, to: day_after)

    expect(days).to eq([])
  end
end
