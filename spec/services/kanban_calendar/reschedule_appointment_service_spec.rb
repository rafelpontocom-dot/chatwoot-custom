require 'rails_helper'

RSpec.describe KanbanCalendar::RescheduleAppointmentService do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:procedure) do
    KanbanCalendarProcedure.create!(
      account: account,
      name: 'Consulta inicial',
      duration_minutes: 50,
      recurrence_allowed: false
    )
  end
  let(:resource) do
    KanbanCalendarResource.create!(
      account: account,
      name: 'Consultorio 1',
      resource_type: 'room',
      timezone: 'America/Sao_Paulo'
    )
  end
  let(:appointment) do
    KanbanCalendar::BookAppointmentService.new(
      account: account,
      contact: contact,
      procedure: procedure,
      resource_ids: [resource.id],
      starts_at: Time.zone.parse('2026-08-10 13:00:00'),
      timezone: 'America/Sao_Paulo'
    ).perform!
  end

  it 'moves an occurrence, increments its version, and records its previous time' do
    new_starts_at = Time.zone.parse('2026-08-11 15:00:00')

    described_class.new(
      appointment: appointment,
      resource_ids: [resource.id],
      starts_at: new_starts_at,
      actor: create(:user, account: account)
    ).perform!

    expect(appointment.reload).to have_attributes(
      starts_at: new_starts_at,
      ends_at: new_starts_at + 50.minutes,
      appointment_version: 2
    )
    expect(appointment.kanban_calendar_appointment_events.last).to have_attributes(
      event_type: 'rescheduled',
      metadata: include('previous_starts_at' => '2026-08-10T13:00:00Z')
    )
  end

  it 'rebuilds the resource reservation with procedure buffers' do
    procedure.update!(buffer_before_minutes: 10, buffer_after_minutes: 15)
    new_starts_at = Time.zone.parse('2026-08-11 15:00:00')

    described_class.new(
      appointment: appointment,
      resource_ids: [resource.id],
      starts_at: new_starts_at
    ).perform!

    expect(appointment.reload.kanban_calendar_appointment_resources.sole).to have_attributes(
      starts_at: new_starts_at - 10.minutes,
      ends_at: new_starts_at + 65.minutes
    )
  end

  it 'rejects a reschedule made from a stale appointment version' do
    expected_lock_version = appointment.lock_version
    appointment.update!(notes: 'Alterada por outro agente')

    expect do
      described_class.new(
        appointment: appointment,
        resource_ids: [resource.id],
        starts_at: Time.zone.parse('2026-08-11 15:00:00'),
        expected_lock_version: expected_lock_version
      ).perform!
    end.to raise_error(ActiveRecord::StaleObjectError)
  end

  it 'creates a derived series when rescheduling this and future appointments' do
    procedure.update!(
      recurrence_allowed: true,
      max_sessions: 10,
      allowed_intervals: ['weekly']
    )
    first_appointment = KanbanCalendar::BookAppointmentService.new(
      account: account,
      contact: contact,
      procedure: procedure,
      resource_ids: [resource.id],
      starts_at: Time.zone.parse('2026-08-10 13:00:00'),
      timezone: 'America/Sao_Paulo',
      occurrence_count: 3,
      interval_kind: 'weekly'
    ).perform!
    second_appointment = first_appointment.kanban_calendar_appointment_series.kanban_calendar_appointments.find_by!(occurrence_number: 2)

    replacement = described_class.new(
      appointment: second_appointment,
      resource_ids: [resource.id],
      starts_at: Time.zone.parse('2026-08-18 15:00:00'),
      scope: 'this_and_future'
    ).perform!

    expect(second_appointment.reload.status).to eq('canceled')
    expect(replacement.kanban_calendar_appointment_series).to have_attributes(planned_count: 2, interval_kind: 'weekly')
  end

  it 'rejects a new time outside the resource working hours' do
    resource.kanban_calendar_availability_rules.create!(
      kind: 'weekly_window',
      weekday: appointment.starts_at.in_time_zone(resource.timezone).wday,
      starts_at_local: '09:00',
      ends_at_local: '12:00'
    )
    unavailable_starts_at = ActiveSupport::TimeZone['America/Sao_Paulo'].parse('2026-08-17 13:00:00')

    expect do
      described_class.new(
        appointment: appointment,
        starts_at: unavailable_starts_at,
        resource_ids: [resource.id]
      ).perform!
    end.to raise_error(ActiveRecord::RecordInvalid, /outside its available hours/)
  end
end
