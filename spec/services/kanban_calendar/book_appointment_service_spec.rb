require 'rails_helper'

RSpec.describe KanbanCalendar::BookAppointmentService do
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
  let(:starts_at) { Time.zone.parse('2026-08-10 13:00:00') }

  it 'creates an appointment and blocks its resource for the procedure duration' do
    appointment = described_class.new(
      account: account,
      contact: contact,
      procedure: procedure,
      resource_ids: [resource.id],
      starts_at: starts_at,
      timezone: 'America/Sao_Paulo'
    ).perform!

    expect(appointment).to have_attributes(
      contact: contact,
      kanban_calendar_procedure: procedure,
      starts_at: starts_at,
      ends_at: starts_at + 50.minutes,
      status: 'scheduled',
      occurrence_number: 1
    )
    expect(appointment.kanban_calendar_appointment_series).to have_attributes(
      account: account,
      contact: contact,
      planned_count: 1,
      status: 'active'
    )
    expect(appointment.kanban_calendar_appointment_resources.pluck(:kanban_calendar_resource_id)).to eq([resource.id])
  end

  it 'rejects an overlapping booking for the same resource' do
    described_class.new(
      account: account,
      contact: contact,
      procedure: procedure,
      resource_ids: [resource.id],
      starts_at: starts_at,
      timezone: 'America/Sao_Paulo'
    ).perform!

    expect do
      described_class.new(
        account: account,
        contact: create(:contact, account: account),
        procedure: procedure,
        resource_ids: [resource.id],
        starts_at: starts_at + 15.minutes,
        timezone: 'America/Sao_Paulo'
      ).perform!
    end.to raise_error(KanbanCalendar::ConflictError)
  end

  it 'creates individual weekly occurrences for a recurring procedure' do
    procedure.update!(
      recurrence_allowed: true,
      max_sessions: 10,
      allowed_intervals: ['weekly']
    )

    first_appointment = described_class.new(
      account: account,
      contact: contact,
      procedure: procedure,
      resource_ids: [resource.id],
      starts_at: starts_at,
      timezone: 'America/Sao_Paulo',
      occurrence_count: 3,
      interval_kind: 'weekly'
    ).perform!

    expect(first_appointment.kanban_calendar_appointment_series).to have_attributes(
      planned_count: 3,
      interval_kind: 'weekly'
    )
    expect(first_appointment.kanban_calendar_appointment_series.kanban_calendar_appointments.order(:occurrence_number).pluck(:starts_at)).to eq(
      [starts_at, starts_at + 1.week, starts_at + 2.weeks]
    )
  end

  it 'requires the linked opportunity board to enable the procedure' do
    card = create(:kanban_card, account: account)

    expect do
      described_class.new(
        account: account,
        contact: contact,
        procedure: procedure,
        resource_ids: [resource.id],
        starts_at: starts_at,
        timezone: 'America/Sao_Paulo',
        kanban_card: card
      ).perform!
    end.to raise_error(ActiveRecord::RecordInvalid, /Calendar is not enabled/)

    card.kanban_board.update!(calendar_enabled: true, calendar_procedure_ids: [procedure.id])

    appointment = described_class.new(
      account: account,
      contact: contact,
      procedure: procedure,
      resource_ids: [resource.id],
      starts_at: starts_at,
      timezone: 'America/Sao_Paulo',
      kanban_card: card
    ).perform!

    expect(appointment.kanban_card).to eq(card)
  end

  it 'does not create an appointment outside a configured resource window' do
    unavailable_starts_at = ActiveSupport::TimeZone['America/Sao_Paulo'].parse('2026-08-10 13:00:00')
    resource.kanban_calendar_availability_rules.create!(
      kind: 'weekly_window',
      weekday: unavailable_starts_at.wday,
      starts_at_local: '09:00',
      ends_at_local: '12:00'
    )

    expect do
      described_class.new(
        account: account,
        contact: contact,
        procedure: procedure,
        resource_ids: [resource.id],
        starts_at: unavailable_starts_at,
        timezone: 'America/Sao_Paulo'
      ).perform!
    end.to raise_error(ActiveRecord::RecordInvalid, /Resources are unavailable/)
  end
end
