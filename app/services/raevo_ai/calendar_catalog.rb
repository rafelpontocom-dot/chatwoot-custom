class RaevoAi::CalendarCatalog
  class InvalidCatalog < StandardError; end

  def initialize(integration:)
    @integration = integration
  end

  def resolve_booking!(booking_key:, board_key:)
    configuration = bookings.fetch(booking_key.to_s, nil)
    validate_booking_configuration!(configuration, board_key)
    procedure = resolved_procedure(configuration)
    resource_ids = resolved_resource_ids(configuration)
    timezone = resolved_timezone(configuration)

    {
      key: booking_key.to_s,
      procedure: procedure,
      resource_ids: resource_ids,
      timezone: timezone
    }
  end

  private

  def bookings
    @integration.settings.fetch('calendar', {}).fetch('bookings', {})
  end

  def validate_booking_configuration!(configuration, board_key)
    raise InvalidCatalog, 'booking is not published in the tenant catalog' if configuration.blank?
    raise InvalidCatalog, 'booking is not authorized for the requested board' unless configuration['board_key'].to_s == board_key.to_s
  end

  def resolved_procedure(configuration)
    procedure = @integration.account.kanban_calendar_procedures.active.find_by(id: positive_integer(configuration['procedure_id']))
    raise InvalidCatalog, 'configured procedure is not active in the integration account' if procedure.blank?

    procedure
  end

  def resolved_resource_ids(configuration)
    resource_ids = Array(configuration['resource_ids']).filter_map { |id| positive_integer(id) }.uniq
    resources = @integration.account.kanban_calendar_resources.active.where(id: resource_ids).to_a
    raise InvalidCatalog, 'configured calendar resources are invalid' if resource_ids.empty? || resources.length != resource_ids.length

    resource_ids
  end

  def resolved_timezone(configuration)
    timezone = configuration['timezone'].to_s
    raise InvalidCatalog, 'configured calendar timezone is invalid' if ActiveSupport::TimeZone[timezone].blank?

    timezone
  end

  def positive_integer(value)
    integer = Integer(value)
    integer.positive? ? integer : nil
  rescue ArgumentError, TypeError
    nil
  end
end
