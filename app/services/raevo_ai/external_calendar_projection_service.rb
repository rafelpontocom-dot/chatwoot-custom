class RaevoAi::ExternalCalendarProjectionService
  class InvalidProjection < StandardError; end

  ALLOWED_PROVIDERS = %w[feegow].freeze

  def initialize(integration:, conversation:, command:)
    @integration = integration
    @conversation = conversation
    @command = command
  end

  def perform
    @booking = calendar_catalog.resolve_booking!(booking_key: booking_key, board_key: board_key)
    validate!
    card = resolved_card

    appointment = ActiveRecord::Base.transaction do
      existing = external_scope.lock.first
      existing ? update_projection!(existing) : create_projection!(@booking, card)
    end

    receipt(appointment)
  rescue ActiveRecord::RecordNotUnique
    raise if @record_not_unique_retried

    @record_not_unique_retried = true
    retry
  end

  private

  def validate!
    raise InvalidProjection, 'provider is not supported' unless provider.in?(ALLOWED_PROVIDERS)
    raise InvalidProjection, 'conversation is not eligible' unless eligible_conversation?
    raise InvalidProjection, 'external_id is required' if external_id.blank?
    raise InvalidProjection, 'source_hash is required' if source_hash.blank?
    raise InvalidProjection, 'ends_at must be after starts_at' unless ends_at > starts_at
    raise InvalidProjection, 'status is invalid' unless status.in?(KanbanCalendarAppointment::STATUSES)
  end

  def eligible_conversation?
    @conversation.account_id == @integration.account_id && @conversation.contact_id.present?
  end

  def create_projection!(booking, card)
    appointment = KanbanCalendar::BookAppointmentService.new(
      account: @integration.account,
      contact: @conversation.contact,
      procedure: booking[:procedure],
      resource_ids: booking[:resource_ids],
      starts_at: starts_at,
      timezone: booking[:timezone],
      kanban_card: card,
      actor: nil,
      dispatch_events: false,
      external_refs: { provider => { 'appointment_id' => external_id } }
    ).perform!
    appointment.update!(projection_attributes.merge(ends_at: ends_at))
    create_sync_event!(appointment, 'created')
    appointment
  end

  def update_projection!(appointment)
    return appointment if stale_or_unchanged?(appointment)

    appointment.update!(projection_attributes.merge(starts_at: starts_at, ends_at: ends_at, appointment_version: appointment.appointment_version + 1))
    appointment.kanban_calendar_appointment_resources.find_each do |reservation|
      procedure = appointment.kanban_calendar_procedure
      reservation.update!(
        starts_at: starts_at - procedure.buffer_before_minutes.minutes,
        ends_at: ends_at + procedure.buffer_after_minutes.minutes,
        appointment_status: status
      )
    end
    create_sync_event!(appointment, 'updated')
    appointment
  end

  def projection_attributes
    {
      status: status,
      source_provider: provider,
      source_external_id: external_id,
      source_read_only: true,
      source_status: @command[:source_status].to_s.presence,
      source_updated_at: source_updated_at,
      source_synced_at: Time.current,
      source_hash: source_hash
    }
  end

  def stale_or_unchanged?(appointment)
    appointment.source_hash == source_hash ||
      (appointment.source_updated_at.present? && source_updated_at.present? && source_updated_at <= appointment.source_updated_at)
  end

  def create_sync_event!(appointment, operation)
    appointment.kanban_calendar_appointment_events.create!(
      account: appointment.account,
      actor: nil,
      event_type: 'external_sync',
      occurred_at: Time.current,
      metadata: { 'provider' => provider, 'operation' => operation, 'action_id' => @command[:action_id] }
    )
  end

  def receipt(appointment)
    {
      'action_id' => @command[:action_id],
      'status' => 'applied',
      'receipts' => {
        'appointment_projection' => {
          'status' => 'projected',
          'appointment_id' => appointment.id,
          'provider' => provider,
          'external_id' => external_id,
          'read_only' => true
        }
      }
    }
  end

  def resolved_card
    board = RaevoAi::CrmCatalog.new(integration: @integration).resolve_board!(board_key)
    RaevoAi::CrmCardResolver.new(integration: @integration, conversation: @conversation, board: board).resolve!
  end

  def external_scope
    @integration.account.kanban_calendar_appointments.where(source_provider: provider, source_external_id: external_id)
  end

  def calendar_catalog = RaevoAi::CalendarCatalog.new(integration: @integration)
  def provider = @command[:provider].to_s
  def external_id = @command[:external_id].to_s
  def board_key = @command[:board_key].to_s
  def booking_key = @command[:booking_key].to_s
  def status = @command[:status].to_s
  def source_hash = @command[:source_hash].to_s
  def starts_at = @starts_at ||= parse_time!(:starts_at)

  def ends_at
    @ends_at ||= @command[:ends_at].present? ? parse_time!(:ends_at) : starts_at + @booking[:procedure].duration_minutes.minutes
  end

  def source_updated_at = @source_updated_at ||= parse_optional_time(:source_updated_at)

  def parse_time!(key)
    Time.iso8601(@command.fetch(key).to_s)
  rescue KeyError, ArgumentError
    raise InvalidProjection, "#{key} must be ISO 8601"
  end

  def parse_optional_time(key)
    return if @command[key].blank?

    Time.iso8601(@command[key].to_s)
  rescue ArgumentError
    raise InvalidProjection, "#{key} must be ISO 8601"
  end
end
