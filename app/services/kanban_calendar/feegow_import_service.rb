# Traz da agenda do Feegow os horários já ocupados e grava-os como bloqueios das
# agendas do Raevo mapeadas a cada profissional.
#
# Como no Google, guarda-se só o intervalo: quem é o paciente está no prontuário,
# e ao Raevo basta saber que aquele horário não cabe mais ninguém. Mostrar o nome
# exigiria casar paciente do Feegow com contato do Chatwoot — outra conversa.
class KanbanCalendar::FeegowImportService
  PROVIDER = 'feegow'.freeze
  PAST_WINDOW = 1.day
  FUTURE_WINDOW = 180.days
  DEFAULT_DURATION_MINUTES = 30
  TIME_ZONE = 'America/Sao_Paulo'.freeze
  CANCELLED_STATUSES = %w[cancelado cancelada faltou desmarcado].freeze

  def initialize(connection:, client: nil, now: Time.current)
    @connection = connection
    @client = client || KanbanCalendar::FeegowClient.new(connection: connection)
    @now = now
  end

  def perform!
    return unless @connection.connected?

    mapped_resources.each { |resource| import_resource(resource) }
    @connection.update!(status: 'connected', last_error: nil, last_imported_at: Time.current)
  rescue KanbanCalendar::FeegowApiError => e
    @connection.update!(status: 'error', last_error: e.message)
    raise
  end

  private

  # Agenda sem profissional do Feegow não tem como saber de quem é o horário.
  def mapped_resources
    @connection.account.kanban_calendar_resources.active.select { |resource| professional_id(resource).present? }
  end

  def professional_id(resource)
    resource.settings.to_h.dig('feegow', 'professional_id').presence
  end

  def import_resource(resource)
    appointments = @client.appointments(
      professional_id: professional_id(resource),
      from: (@now - PAST_WINDOW).to_date,
      to: (@now + FUTURE_WINDOW).to_date
    )
    replace_blocks(resource, appointments.filter_map { |appointment| busy_block(appointment) })
  end

  def busy_block(appointment)
    return if cancelled?(appointment)

    starts_at = parse_time(appointment['data'], appointment['horario'])
    return if starts_at.blank?

    {
      external_event_id: appointment['agendamento_id'].to_s,
      starts_at: starts_at,
      ends_at: starts_at + duration_minutes(appointment).minutes,
      all_day: false
    }
  end

  def cancelled?(appointment)
    status = appointment['status'].to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, '').strip.downcase
    CANCELLED_STATUSES.include?(status)
  end

  def duration_minutes(appointment)
    minutes = appointment['duracao'].to_i
    minutes.positive? ? minutes : DEFAULT_DURATION_MINUTES
  end

  # O Feegow devolve data em dd-mm-aaaa e hora no fuso da clínica.
  def parse_time(date, time)
    match = /\A(\d{2})-(\d{2})-(\d{4})\z/.match(date.to_s.strip)
    clock = /\A(\d{2}):(\d{2})/.match(time.to_s.strip)
    return if match.blank? || clock.blank?

    zone.local(match[3].to_i, match[2].to_i, match[1].to_i, clock[1].to_i, clock[2].to_i)
  end

  def zone
    @zone ||= ActiveSupport::TimeZone[TIME_ZONE] || Time.zone
  end

  def replace_blocks(resource, blocks)
    KanbanCalendarExternalBusyBlock.transaction do
      scope = KanbanCalendarExternalBusyBlock.where(kanban_calendar_resource_id: resource.id, provider: PROVIDER)
      scope.where.not(external_event_id: blocks.pluck(:external_event_id)).delete_all
      next if blocks.empty?

      KanbanCalendarExternalBusyBlock.upsert_all( # rubocop:disable Rails/SkipsModelValidations
        blocks.map { |block| block.merge(account_id: resource.account_id, kanban_calendar_resource_id: resource.id, provider: PROVIDER) },
        unique_by: :idx_calendar_busy_blocks_on_resource_provider_event
      )
    end
  end
end
