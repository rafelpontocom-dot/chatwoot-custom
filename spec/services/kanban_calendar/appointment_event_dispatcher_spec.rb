require 'rails_helper'

RSpec.describe KanbanCalendar::AppointmentEventDispatcher do
  it 'enqueues Google Calendar export for an appointment using a connected agenda' do
    resources = instance_double(ActiveRecord::Relation)
    appointment = instance_double(
      KanbanCalendarAppointment,
      id: 44,
      kanban_card: nil,
      kanban_calendar_resources: resources
    )
    allow(resources).to receive(:joins).with(:kanban_calendar_google_connection).and_return(resources)
    allow(resources).to receive(:exists?).with(kanban_calendar_google_connections: { status: 'connected' }).and_return(true)
    allow(KanbanCalendar::SyncGoogleCalendarAppointmentJob).to receive(:perform_later)

    described_class.new(appointment: appointment, event_type: 'created').dispatch

    expect(KanbanCalendar::SyncGoogleCalendarAppointmentJob).to have_received(:perform_later).with(44)
  end
end
