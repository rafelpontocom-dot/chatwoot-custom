# Traz as mudanças feitas no Google a cada ciclo do agendador (cinco minutos).
class KanbanCalendar::ImportAllGoogleCalendarsJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    KanbanCalendarGoogleConnection.where(status: 'connected').find_each do |connection|
      KanbanCalendar::ImportGoogleCalendarEventsJob.perform_later(connection.id)
    end
  end
end
