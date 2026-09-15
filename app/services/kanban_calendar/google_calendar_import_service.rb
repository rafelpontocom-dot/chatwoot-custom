# Traz da agenda Google os horários em que a pessoa está ocupada e grava-os como
# bloqueios do recurso. É isto que impede a secretária, a página pública e a IA
# de marcarem por cima de um compromisso que só existe no Google.
#
# Reimporta a janela inteira de cada vez e apaga o que já não veio: é o que trata
# um evento movido ou apagado no Google sem precisar de guardar estado de sync.
class KanbanCalendar::GoogleCalendarImportService
  PAST_WINDOW = 1.day
  FUTURE_WINDOW = 180.days
  NON_BLOCKING_EVENT_TYPES = %w[workingLocation].freeze

  def initialize(connection:, client: nil, now: Time.current)
    @connection = connection
    @client = client || KanbanCalendar::GoogleCalendarClient.new(connection: connection)
    @now = now
  end

  def perform!
    return unless @connection.connected?

    response = @client.list_events(time_min: @now - PAST_WINDOW, time_max: @now + FUTURE_WINDOW)
    replace_blocks(busy_blocks(response[:items], response[:time_zone]))
    @connection.update!(status: 'connected', last_error: nil, last_imported_at: Time.current)
  rescue KanbanCalendar::GoogleCalendarApiError => e
    @connection.update!(status: 'error', last_error: e.message)
    raise
  end

  private

  def busy_blocks(items, calendar_time_zone)
    zone = ActiveSupport::TimeZone[calendar_time_zone.presence || @connection.kanban_calendar_resource.timezone] || Time.zone
    items.filter_map { |item| busy_block(item, zone) }
  end

  def busy_block(item, zone)
    return unless blocking?(item)

    starts_at, ends_at, all_day = interval(item, zone)
    return if starts_at.blank? || ends_at.blank? || ends_at <= starts_at

    { external_event_id: item['id'], starts_at: starts_at, ends_at: ends_at, all_day: all_day }
  end

  def blocking?(item)
    item['status'] != 'cancelled' &&
      item['transparency'] != 'transparent' &&
      NON_BLOCKING_EVENT_TYPES.exclude?(item['eventType']) &&
      item.dig('extendedProperties', 'private', 'raevo_appointment_id').blank? &&
      !declined?(item)
  end

  def declined?(item)
    Array(item['attendees']).any? { |attendee| attendee['self'] && attendee['responseStatus'] == 'declined' }
  end

  # Evento de dia inteiro vem como data, com o fim exclusivo: 20 a 22 ocupa os
  # dias 20 e 21, da meia-noite à meia-noite no fuso da agenda.
  def interval(item, zone)
    if item.dig('start', 'date')
      [zone.parse(item.dig('start', 'date')), zone.parse(item.dig('end', 'date').to_s), true]
    else
      [parse_time(item.dig('start', 'dateTime')), parse_time(item.dig('end', 'dateTime')), false]
    end
  end

  def parse_time(value)
    Time.iso8601(value.to_s).in_time_zone
  rescue ArgumentError
    nil
  end

  def replace_blocks(blocks)
    KanbanCalendarExternalBusyBlock.transaction do
      @connection.kanban_calendar_external_busy_blocks.where.not(external_event_id: blocks.pluck(:external_event_id)).delete_all
      next if blocks.empty?

      # Um upsert por janela em vez de um save por evento: uma agenda cheia traz
      # centenas. O intervalo já foi validado em `busy_block`.
      KanbanCalendarExternalBusyBlock.upsert_all( # rubocop:disable Rails/SkipsModelValidations
        blocks.map { |block| block.merge(block_owner) },
        unique_by: :idx_calendar_busy_blocks_on_connection_event
      )
    end
  end

  def block_owner
    {
      account_id: @connection.account_id,
      kanban_calendar_resource_id: @connection.kanban_calendar_resource_id,
      kanban_calendar_google_connection_id: @connection.id
    }
  end
end
