class KanbanCalendar::BackfillGoogleCalendarConnectionJob < ApplicationJob
  queue_as :default

  def perform(connection_id)
    connection = KanbanCalendarGoogleConnection.find(connection_id)
    return unless connection.connected?

    connection.kanban_calendar_resource.kanban_calendar_appointments.active.where('ends_at > ?', Time.current).find_each do |appointment|
      KanbanCalendar::GoogleCalendarSyncService.new(appointment: appointment, connection: connection).perform!
    end
  end
end
