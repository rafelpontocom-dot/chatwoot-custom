require 'rails_helper'

RSpec.describe KanbanCalendar::UpdateAppointmentStatusService do
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

  it 'cancels an appointment and releases its resource reservation' do
    result = described_class.new(
      appointment: appointment,
      action: 'cancel',
      cancellation_reason: 'Paciente solicitou',
      actor: create(:user, account: account)
    ).perform!

    expect(result.status).to eq('canceled')
    expect(appointment.reload).to have_attributes(status: 'canceled', cancellation_reason: 'Paciente solicitou')
    expect(appointment.kanban_calendar_appointment_resources.pluck(:appointment_status)).to eq(['canceled'])
    expect(appointment.kanban_calendar_appointment_events.last.event_type).to eq('canceled')
  end

  it 'rejects a cancellation without a reason' do
    expect do
      described_class.new(appointment: appointment, action: 'cancel').perform!
    end.to raise_error(ActiveRecord::RecordInvalid)
  end

  it 'marks an appointment as completed' do
    result = described_class.new(appointment: appointment, action: 'complete').perform!

    expect(result).to have_attributes(status: 'completed', completed_at: be_present)
    expect(appointment.reload.kanban_calendar_appointment_events.last.event_type).to eq('completed')
  end

  it 'marks an appointment as a no-show' do
    result = described_class.new(appointment: appointment, action: 'no_show').perform!

    expect(result).to have_attributes(status: 'no_show', no_show_at: be_present)
    expect(appointment.reload.kanban_calendar_appointment_events.last.event_type).to eq('no_show')
  end
end
