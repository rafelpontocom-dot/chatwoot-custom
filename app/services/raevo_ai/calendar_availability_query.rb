class RaevoAi::CalendarAvailabilityQuery
  MAX_DAYS = 14

  class InvalidAvailability < StandardError; end

  def initialize(integration:, conversation:, command:)
    @integration = integration
    @conversation = conversation
    @board_key = command.fetch(:board_key)
    @booking_key = command.fetch(:booking_key)
    @starts_on = parse_date(command.fetch(:starts_on))
    @ends_on = parse_date(command.fetch(:ends_on))
  end

  def call
    booking = RaevoAi::CalendarCatalog.new(integration: @integration).resolve_booking!(booking_key: @booking_key, board_key: @board_key)
    validate_calendar_context!(booking)

    {
      booking_key: booking[:key],
      timezone: booking[:timezone],
      slots: dates.flat_map { |date| available_slots_for(booking, date) }.sort.map { |slot| slot.in_time_zone(booking[:timezone]).iso8601 }
    }
  end

  private

  def validate_calendar_context!(booking)
    raise InvalidAvailability, 'conversation is not eligible for a booking in this integration account' unless eligible_conversation?

    card = resolved_card
    KanbanCalendar::BoardConfigurationValidator.new(card: card, procedure: booking[:procedure]).validate!
  end

  def eligible_conversation?
    @conversation.account_id == @integration.account_id && @conversation.contact_id.present?
  end

  def resolved_card
    board = RaevoAi::CrmCatalog.new(integration: @integration).resolve_board!(@board_key)
    RaevoAi::CrmCardResolver.new(integration: @integration, conversation: @conversation, board: board).resolve!
  end

  def dates
    raise InvalidAvailability, 'ends_on must not precede starts_on' if @ends_on < @starts_on
    raise InvalidAvailability, "availability range cannot exceed #{MAX_DAYS} days" if (@ends_on - @starts_on).to_i >= MAX_DAYS

    (@starts_on..@ends_on)
  end

  def available_slots_for(booking, date)
    resources = @integration.account.kanban_calendar_resources.active.where(id: booking[:resource_ids]).to_a
    resources.map { |resource| slots_for_resource(resource, booking[:procedure], date) }
             .reduce { |intersection, slots| intersection & slots } || []
  end

  def slots_for_resource(resource, procedure, date)
    KanbanCalendar::AvailabilitySlotsQuery.new(resource: resource, procedure: procedure, date: date).call.map(&:utc)
  end

  def parse_date(value)
    Date.iso8601(value.to_s)
  rescue Date::Error
    raise InvalidAvailability, 'date must use ISO 8601 format'
  end
end
