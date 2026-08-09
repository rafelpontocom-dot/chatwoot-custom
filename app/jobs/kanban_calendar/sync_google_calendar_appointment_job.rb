class KanbanCalendar::SyncGoogleCalendarAppointmentJob < ApplicationJob
  queue_as :default

  def perform(appointment_id)
    appointment = KanbanCalendarAppointment.includes(
      :contact,
      :kanban_calendar_procedure,
      kanban_calendar_resources: :kanban_calendar_google_connection
    ).find(appointment_id)

    appointment.kanban_calendar_resources.each do |resource|
      connection = resource.kanban_calendar_google_connection
      next unless connection&.connected?

      KanbanCalendar::GoogleCalendarSyncService.new(appointment: appointment, connection: connection).perform!
    end
  end
end
