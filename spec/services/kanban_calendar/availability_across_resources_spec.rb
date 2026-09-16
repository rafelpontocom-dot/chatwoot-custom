require 'rails_helper'

RSpec.describe KanbanCalendar::AvailabilityAcrossResources do
  let(:account) { create(:account) }
  let(:timezone) { 'America/Sao_Paulo' }
  let(:date) { Date.new(2026, 8, 10) }
  let(:procedure) { KanbanCalendarProcedure.create!(account: account, name: 'Toxina', duration_minutes: 50) }
  let(:professional) do
    KanbanCalendarResource.create!(account: account, name: 'Dra. Ana', resource_type: 'user', timezone: timezone)
  end
  let(:room) do
    KanbanCalendarResource.create!(account: account, name: 'Sala 1', resource_type: 'room', timezone: timezone)
  end

  before do
    # A agenda nasce com a semana comercial; estes exemplos definem a sua.
    [professional, room].each { |resource| resource.kanban_calendar_availability_rules.delete_all }
    professional.kanban_calendar_availability_rules.create!(
      kind: 'weekly_window', weekday: date.wday, starts_at_local: '09:00', ends_at_local: '11:00'
    )
    room.kanban_calendar_availability_rules.create!(
      kind: 'weekly_window', weekday: date.wday, starts_at_local: '10:00', ends_at_local: '12:00'
    )
  end

  def local_times(slots)
    slots.map { |slot| slot.in_time_zone(timezone).strftime('%H:%M') }
  end

  # A consulta ocupa a profissional e a sala ao mesmo tempo. Os horários livres
  # de só uma delas mentiam: deixavam escolher uma hora em que a outra estava
  # ocupada, e o agendamento só falhava no fim, por conflito.
  it 'offers only the starts where every resource is free' do
    slots = described_class.new(procedure: procedure, resources: [professional, room]).slots(date: date)

    expect(local_times(slots)).to eq(['10:00'])
  end

  it 'behaves like the single-resource query when there is only one resource' do
    slots = described_class.new(procedure: procedure, resources: [professional]).slots(date: date)
    sozinha = KanbanCalendar::AvailabilitySlotsQuery.new(resource: professional, procedure: procedure, date: date).call

    expect(slots).to eq(sozinha)
  end

  it 'is not available at a start where one of the resources is outside its hours' do
    starts_at = ActiveSupport::TimeZone[timezone].parse('2026-08-10 09:00:00')

    result = described_class.new(procedure: procedure, resources: [professional, room]).check(starts_at: starts_at)

    expect(result[:available]).to be(false)
  end

  it 'is available at a start where every resource is free' do
    starts_at = ActiveSupport::TimeZone[timezone].parse('2026-08-10 10:00:00')

    result = described_class.new(procedure: procedure, resources: [professional, room]).check(starts_at: starts_at)

    expect(result).to include(available: true, conflict: false, resource_allowed: true)
  end
end
