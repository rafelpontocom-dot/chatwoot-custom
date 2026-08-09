class KanbanCalendar::PublicBookingService
  def initialize(booking_page:, procedure:, booking:)
    @booking_page = booking_page
    @procedure = procedure
    @contact_attributes = booking.fetch(:contact_attributes, {}).to_h.symbolize_keys
    @resource_ids = Array(booking[:resource_ids]).map(&:to_i).uniq
    @starts_at = booking[:starts_at]
    @timezone = booking[:timezone]
  end

  def perform!
    validate_references!

    appointment = ActiveRecord::Base.transaction do
      @contact = find_or_create_contact!
      @card = find_or_create_card!
      KanbanCalendar::BookAppointmentService.new(
        account: account,
        contact: @contact,
        procedure: procedure,
        resource_ids: resource_ids,
        starts_at: starts_at,
        timezone: timezone,
        kanban_card: @card,
        dispatch_events: false,
        external_refs: booking_metadata
      ).perform!
    end

    dispatch_card_created_event if @created_card
    KanbanCalendar::AppointmentEventDispatcher.new(appointment: appointment, event_type: 'created').dispatch
    appointment
  end

  private

  attr_reader :booking_page, :procedure, :contact_attributes, :resource_ids, :starts_at, :timezone

  def account
    booking_page.account
  end

  def validate_references!
    validate_booking_page!
    validate_procedure!
    validate_contact!
    validate_schedule!
    validate_crm_destination!
  end

  def validate_booking_page!
    invalid!('Booking page is not active') unless booking_page.active?
  end

  def validate_procedure!
    return if procedure.account_id == account.id && procedure.active? && procedure.public_booking_enabled?

    invalid!('Procedure is not available for public booking')
  end

  def validate_contact!
    return if contact_attributes[:name].present? && contact_lookup_values.present?

    invalid!('A name and phone or email are required')
  end

  def validate_schedule!
    return if starts_at.present? && timezone.present?

    invalid!('A valid date and timezone are required')
  end

  def validate_crm_destination!
    [booking_page.kanban_board, booking_page.kanban_stage, booking_page.inbox].each do |record|
      invalid!('Booking page CRM destination is incomplete') if record.blank?
    end
    invalid!('Booking page funnel is not active') unless booking_page.kanban_board.active?
    invalid!('Booking page stage is not active') unless booking_page.kanban_stage.active?
    invalid!('Booking page inbox is not allowed by the funnel') unless booking_page.kanban_board.inbox_allowed?(booking_page.inbox)
  end

  def find_or_create_contact!
    contact = existing_contact || account.contacts.create!(contact_attributes.slice(:name, :email, :phone_number))
    return contact if contact_attributes[:custom_attributes].blank?

    contact.update!(custom_attributes: contact.custom_attributes.merge(contact_attributes[:custom_attributes]))
    contact
  end

  def existing_contact
    return account.contacts.from_email(contact_attributes[:email]) if contact_attributes[:email].present?

    account.contacts.find_by(phone_number: contact_attributes[:phone_number]) if contact_attributes[:phone_number].present?
  end

  def contact_lookup_values
    contact_attributes.values_at(:email, :phone_number).compact_blank
  end

  def find_or_create_card!
    return matching_card if matching_card

    create_card!
  end

  def matching_card
    return if booking_page.create_new?

    scope = account.kanban_cards.where(contact: @contact, kanban_board: booking_page.kanban_board)
    scope = scope.open_opportunities if booking_page.open_or_recent?
    scope.order(created_at: :desc, id: :desc).first
  end

  def create_card!
    stage = booking_page.kanban_stage
    stage.lock!
    KanbanCard.lock_active_cards_for_stages!(booking_page.kanban_board, [stage.id])
    KanbanCard.where(kanban_board: booking_page.kanban_board, kanban_stage: stage).active.update_all( # rubocop:disable Rails/SkipsModelValidations
      ['position = position + 1, updated_at = ?', Time.current]
    )
    @created_card = KanbanCard.create!(
      account: account,
      kanban_board: booking_page.kanban_board,
      kanban_stage: stage,
      contact: @contact,
      inbox: booking_page.inbox,
      subject: public_subject,
      origin: 'manual',
      position: 1,
      active: true
    )
  end

  def public_subject
    title = procedure.public_title.presence || procedure.name
    "#{title} - #{starts_at.in_time_zone(timezone).strftime('%d/%m/%Y %H:%M')}"
  end

  def booking_metadata
    {
      'source' => 'public_booking',
      'booking_page_id' => booking_page.id,
      'procedure_slug' => procedure.public_slug,
      'duplicate_policy' => booking_page.duplicate_policy
    }
  end

  def dispatch_card_created_event
    Rails.configuration.dispatcher.dispatch(
      Events::Types::KANBAN_CARD_CREATED,
      Time.zone.now,
      account_id: @created_card.account_id,
      board_id: @created_card.kanban_board_id,
      stage_id: @created_card.kanban_stage_id,
      card_id: @created_card.id,
      conversation_id: @created_card.conversation_id
    )
  end

  def invalid!(message)
    procedure.errors.add(:base, message)
    raise ActiveRecord::RecordInvalid, procedure
  end
end
