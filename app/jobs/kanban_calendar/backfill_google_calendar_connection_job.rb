class KanbanCalendar::BackfillGoogleCalendarConnectionJob < ApplicationJob
  queue_as :default

  def perform(connection_id)
    connection = KanbanCalendarGoogleConnection.find(connection_id)
    return unless connection.connected?

    # Qualificada: as reservas também têm `ends_at`, e sem o nome da tabela o
    # Postgres recusava a consulta — ligar a agenda nunca exportava nada.
    connection.kanban_calendar_resource.kanban_calendar_appointments.active
              .where('kanban_calendar_appointments.ends_at > ?', Time.current).find_each do |appointment|
      KanbanCalendar::GoogleCalendarSyncService.new(appointment: appointment, connection: connection).perform!
    end
  end
end
