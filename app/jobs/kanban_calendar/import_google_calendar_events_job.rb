class KanbanCalendar::ImportGoogleCalendarEventsJob < ApplicationJob
  queue_as :default

  def perform(connection_id)
    connection = KanbanCalendarGoogleConnection.find_by(id: connection_id)
    return unless connection&.connected?

    KanbanCalendar::GoogleCalendarImportService.new(connection: connection).perform!
  rescue KanbanCalendar::GoogleCalendarApiError
    # O erro fica na conexão, à vista nas configurações. Repetir aqui só enchia a
    # fila: a próxima importação já vem daqui a cinco minutos.
    nil
  end
end
