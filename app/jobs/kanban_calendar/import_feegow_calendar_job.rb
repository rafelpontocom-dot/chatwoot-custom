class KanbanCalendar::ImportFeegowCalendarJob < ApplicationJob
  queue_as :default

  def perform(connection_id)
    connection = KanbanCalendarFeegowConnection.find_by(id: connection_id)
    return unless connection&.connected?

    KanbanCalendar::FeegowImportService.new(connection: connection).perform!
  rescue KanbanCalendar::FeegowApiError
    # O motivo fica na conexão, à vista nas configurações. A próxima importação
    # vem daqui a cinco minutos; repetir agora só encheria a fila.
    nil
  end
end
