require 'rails_helper'

RSpec.describe KanbanCalendar::AvailabilitySlotsQuery do
  let(:account) { create(:account) }
  let(:resource) do
    KanbanCalendarResource.create!(
      account: account,
      name: 'Consultorio 1',
      resource_type: 'room',
      timezone: 'America/Sao_Paulo'
    )
  end
  let(:procedure) do
    KanbanCalendarProcedure.create!(
      account: account,
      name: 'Consulta',
      duration_minutes: 50
    )
  end
  let(:date) { Date.new(2026, 8, 10) }
  let(:resource_timezone) { ActiveSupport::TimeZone[resource.timezone] }

  # A agenda nasce com a semana comercial; cada exemplo define a janela que testa.
  before { resource.kanban_calendar_availability_rules.delete_all }

  it 'returns free starts that fit the configured working window' do
    resource.kanban_calendar_availability_rules.create!(
      kind: 'weekly_window',
      weekday: date.wday,
      starts_at_local: '09:00',
      ends_at_local: '11:00'
    )

    slots = described_class.new(resource: resource, procedure: procedure, date: date).call

    expect(slots.map { |slot| slot.in_time_zone(resource.timezone).strftime('%H:%M') })
      .to eq(['09:00', '09:15', '09:30', '09:45', '10:00'])
  end

  it 'keeps the configured buffers inside the working window' do
    procedure.update!(buffer_before_minutes: 10, buffer_after_minutes: 10)
    resource.kanban_calendar_availability_rules.create!(
      kind: 'weekly_window',
      weekday: date.wday,
      starts_at_local: '09:00',
      ends_at_local: '11:00'
    )

    slots = described_class.new(resource: resource, procedure: procedure, date: date).call

    expect(slots.map { |slot| slot.in_time_zone(resource.timezone).strftime('%H:%M') })
      .to eq(['09:10', '09:25', '09:40', '09:55'])
  end

  # O espaçamento estava escrito no código em 15 minutos, e a configuração que
  # existia na página de agendamento não era lida por ninguém.
  it 'offers the starts spaced as the agenda asks' do
    resource.update!(slot_interval_minutes: 60)
    resource.kanban_calendar_availability_rules.create!(
      kind: 'weekly_window',
      weekday: date.wday,
      starts_at_local: '09:00',
      ends_at_local: '12:00'
    )

    slots = described_class.new(resource: resource, procedure: procedure, date: date).call

    expect(slots.map { |slot| slot.in_time_zone(resource.timezone).strftime('%H:%M') }).to eq(['09:00', '10:00', '11:00'])
  end

  it 'falls back to the spacing configured for the account when the agenda has none' do
    KanbanCalendarBookingPage.create!(account: account, public_token: SecureRandom.hex(8), slot_interval_minutes: 30)
    resource.kanban_calendar_availability_rules.create!(
      kind: 'weekly_window',
      weekday: date.wday,
      starts_at_local: '09:00',
      ends_at_local: '11:00'
    )

    slots = described_class.new(resource: resource, procedure: procedure, date: date).call

    expect(slots.map { |slot| slot.in_time_zone(resource.timezone).strftime('%H:%M') }).to eq(['09:00', '09:30', '10:00'])
  end

  it 'omits starts that overlap a busy time imported from Google Calendar' do
    resource.kanban_calendar_availability_rules.create!(
      kind: 'weekly_window',
      weekday: date.wday,
      starts_at_local: '09:00',
      ends_at_local: '11:00'
    )
    KanbanCalendarExternalBusyBlock.create!(
      account: account, kanban_calendar_resource: resource, provider: 'google_calendar',
      external_event_id: 'dentista', starts_at: resource_timezone.local(2026, 8, 10, 9, 30), ends_at: resource_timezone.local(2026, 8, 10, 10, 0)
    )

    slots = described_class.new(resource: resource, procedure: procedure, date: date).call

    expect(slots.map { |slot| slot.in_time_zone(resource.timezone).strftime('%H:%M') }).to eq(['10:00'])
  end

  it 'omits starts occupied by an active appointment' do
    resource.kanban_calendar_availability_rules.create!(
      kind: 'weekly_window',
      weekday: date.wday,
      starts_at_local: '09:00',
      ends_at_local: '12:00'
    )
    contact = create(:contact, account: account)
    series = account.kanban_calendar_appointment_series.create!(
      contact: contact,
      kanban_calendar_procedure: procedure,
      planned_count: 1,
      interval_kind: 'once',
      timezone: resource.timezone,
      started_at: resource_timezone.parse('2026-08-10 09:00:00')
    )
    appointment = series.kanban_calendar_appointments.create!(
      account: account,
      contact: contact,
      kanban_calendar_procedure: procedure,
      starts_at: resource_timezone.parse('2026-08-10 09:00:00'),
      ends_at: resource_timezone.parse('2026-08-10 09:50:00'),
      timezone: resource.timezone,
      occurrence_number: 1
    )
    appointment.kanban_calendar_appointment_resources.create!(
      kanban_calendar_resource: resource,
      starts_at: appointment.starts_at,
      ends_at: appointment.ends_at,
      appointment_status: appointment.status
    )

    slots = described_class.new(resource: resource, procedure: procedure, date: date).call
    start_times = slots.map { |slot| slot.in_time_zone(resource.timezone).strftime('%H:%M') }

    expect(start_times).not_to include('09:00', '09:15')
    expect(start_times).to include('10:00')
  end
end
