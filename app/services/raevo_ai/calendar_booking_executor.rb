class RaevoAi::CalendarBookingExecutor
  class InvalidBooking < StandardError; end

  def initialize(integration:, conversation:, command:)
    @integration = integration
    @conversation = conversation
    @action_id = command.fetch(:action_id)
    @board_key = command.fetch(:board_key)
    @booking_key = command.fetch(:booking_key)
    @starts_at = parse_starts_at(command.fetch(:starts_at))
  end

  def perform
    booking = RaevoAi::CalendarCatalog.new(integration: @integration).resolve_booking!(booking_key: @booking_key, board_key: @board_key)
    card = resolved_card
    claim = RaevoAi::CommandRecorder.new(
      integration: @integration,
      action_id: @action_id,
      command_type: 'calendar.book_appointment',
      payload: command_payload(booking, card)
    ).claim

    return claim.command.result if claim.command.state == 'applied'

    apply_claim!(claim.command, booking, card)
  end

  private

  def resolved_card
    board = RaevoAi::CrmCatalog.new(integration: @integration).resolve_board!(@board_key)
    validate_conversation!
    RaevoAi::CrmCardResolver.new(integration: @integration, conversation: @conversation, board: board).resolve!
  end

  def validate_conversation!
    return if @conversation.account_id == @integration.account_id && @conversation.contact_id.present?

    raise InvalidBooking, 'conversation is not eligible for a booking in this integration account'
  end

  def parse_starts_at(value)
    Time.iso8601(value.to_s)
  rescue ArgumentError
    raise InvalidBooking, 'starts_at must be ISO 8601'
  end

  def apply_claim!(claimed_command, booking, card)
    RaevoAiCommand.transaction do
      command = claimed_command.lock!
      command.state == 'applied' ? command.result : apply_pending_command!(command, booking, card)
    end
  end

  def apply_pending_command!(command, booking, card)
    appointment = KanbanCalendar::BookAppointmentService.new(
      account: @integration.account,
      contact: @conversation.contact,
      procedure: booking[:procedure],
      resource_ids: booking[:resource_ids],
      starts_at: @starts_at,
      timezone: booking[:timezone],
      kanban_card: card,
      actor: nil,
      external_refs: {
        'raevo_ai' => { 'action_id' => @action_id, 'booking_key' => booking[:key] }
      }
    ).perform!
    result = receipt(appointment)
    command.update!(state: 'applied', result: result)
    result
  end

  def command_payload(booking, card)
    {
      'conversation_id' => @conversation.display_id,
      'card_id' => card.id,
      'board_key' => @board_key,
      'booking_key' => booking[:key],
      'procedure_id' => booking[:procedure].id,
      'resource_ids' => booking[:resource_ids],
      'starts_at' => @starts_at.iso8601,
      'timezone' => booking[:timezone]
    }
  end

  def receipt(appointment)
    {
      'action_id' => @action_id,
      'status' => 'applied',
      'receipts' => {
        'appointment' => {
          'status' => 'created',
          'appointment_id' => appointment.id,
          'starts_at' => appointment.starts_at.iso8601
        }
      }
    }
  end
end
