# Traz o que mudou no Feegow a cada ciclo do agendador (cinco minutos).
class KanbanCalendar::ImportAllFeegowCalendarsJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    KanbanCalendarFeegowConnection.where(status: 'connected').find_each do |connection|
      KanbanCalendar::ImportFeegowCalendarJob.perform_later(connection.id)
    end
  end
end
