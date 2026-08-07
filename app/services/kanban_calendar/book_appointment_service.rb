class KanbanCalendar::BookAppointmentService
  def initialize(account:, contact:, procedure:, **attributes)
    @account = account
    @contact = contact
    @procedure = procedure
    @resource_ids = Array(attributes.fetch(:resource_ids)).map(&:to_i).uniq
    @starts_at = attributes.fetch(:starts_at)
    @timezone = attributes.fetch(:timezone)
    @occurrence_count = (attributes.fetch(:occurrence_count, 1).presence || 1).to_i
    @interval_kind = attributes.fetch(:interval_kind, 'once').presence || 'once'
    @interval_days = attributes[:interval_days].presence&.to_i
    @kanban_card = attributes[:kanban_card]
    @actor = attributes[:actor]
  end

  def perform!
    validate_references!

    ActiveRecord::Base.transaction do
      raise KanbanCalendar::ConflictError, conflicting_resource_ids if conflicting_resource_ids.any?

      series = build_series
      appointments = appointment_starts.each_with_index.map do |occurrence_starts_at, index|
        build_appointment(series, occurrence_starts_at, index + 1)
      end
      appointments.each do |appointment|
        appointment.save!
        create_resource_reservations!(appointment)
        create_event!(appointment)
      end
      appointments.first
    end
  rescue ActiveRecord::StatementInvalid => e
    raise unless e.cause.is_a?(PG::ExclusionViolation)

    raise KanbanCalendar::ConflictError, @resource_ids
  end

  private

  def validate_references!
    validate_account_references!
    validate_board_calendar_configuration!
    validate_resources!
    validate_procedure_resources!
    validate_recurrence!
  end

  def validate_account_references!
    [@procedure, @contact, @kanban_card].compact.each do |record|
      raise ActiveRecord::RecordInvalid, record unless record.account_id == @account.id
    end
  end

  def validate_resources!
    return unless @resource_ids.empty? || resources.length != @resource_ids.length

    raise ActiveRecord::RecordInvalid, @procedure
  end

  def validate_board_calendar_configuration!
    return unless @kanban_card

    board = @kanban_card.kanban_board
    return if board.calendar_module_enabled? && board_allows_procedure?(board)

    @kanban_card.errors.add(:base, 'Calendar is not enabled for this funnel or procedure')
    raise ActiveRecord::RecordInvalid, @kanban_card
  end

  def board_allows_procedure?(board)
    board.configured_calendar_procedure_ids.empty? ||
      @procedure.id.in?(board.configured_calendar_procedure_ids)
  end

  def validate_procedure_resources!
    return unless restricted_procedure_resources? && (resources - @procedure.kanban_calendar_resources).any?

    raise ActiveRecord::RecordInvalid, @procedure
  end

  def validate_recurrence!
    validate_occurrence_count!
    return if @occurrence_count == 1 && @interval_kind == 'once'

    validate_procedure_recurrence!
    validate_recurrence_interval!
  end

  def validate_occurrence_count!
    invalid_recurrence!('must be between 1 and 100') unless @occurrence_count.between?(1, 100)
  end

  def validate_procedure_recurrence!
    invalid_recurrence!('does not allow recurrence') unless @procedure.recurrence_allowed?
    return unless @procedure.max_sessions && @occurrence_count > @procedure.max_sessions

    invalid_recurrence!('exceeds the procedure maximum')
  end

  def validate_recurrence_interval!
    invalid_recurrence!('is not supported') unless supported_recurrence_interval?
    invalid_recurrence!('is not allowed for this procedure') unless recurrence_allowed_for_procedure?
    return unless @interval_kind == 'days' && !@interval_days.to_i.positive?

    invalid_recurrence!('must be greater than zero')
  end

  def supported_recurrence_interval?
    KanbanCalendarAppointmentSeries::INTERVAL_KINDS.include?(@interval_kind) && @interval_kind != 'once'
  end

  def recurrence_allowed_for_procedure?
    allowed_intervals = @procedure.allowed_intervals
    return true if allowed_intervals.empty? || @interval_kind.in?(allowed_intervals)

    @interval_kind == 'days' && "days:#{@interval_days}".in?(allowed_intervals)
  end

  def invalid_recurrence!(message)
    @procedure.errors.add(:base, "Recurrence #{message}")
    raise ActiveRecord::RecordInvalid, @procedure
  end

  def resources
    @resources ||= @account.kanban_calendar_resources.active.where(id: @resource_ids).to_a
  end

  def restricted_procedure_resources?
    @procedure.kanban_calendar_resources.exists?
  end

  def conflicting_resource_ids
    appointment_starts.flat_map do |occurrence_starts_at|
      KanbanCalendarAppointmentResource.where(kanban_calendar_resource_id: @resource_ids)
                                       .where(appointment_status: KanbanCalendarAppointment::ACTIVE_STATUSES)
                                       .where('starts_at < ? AND ends_at > ?', occurrence_ends_at(occurrence_starts_at), occurrence_starts_at)
                                       .distinct
                                       .pluck(:kanban_calendar_resource_id)
    end.uniq
  end

  def appointment_starts
    @appointment_starts ||= Array.new(@occurrence_count) do |index|
      case @interval_kind
      when 'weekly' then @starts_at + index.weeks
      when 'biweekly' then @starts_at + (index * 2).weeks
      when 'monthly' then @starts_at.advance(months: index)
      when 'days' then @starts_at + (index * @interval_days).days
      else @starts_at
      end
    end
  end

  def occurrence_ends_at(occurrence_starts_at)
    occurrence_starts_at + @procedure.duration_minutes.minutes
  end

  def build_series
    @account.kanban_calendar_appointment_series.create!(
      contact: @contact,
      kanban_card: @kanban_card,
      kanban_calendar_procedure: @procedure,
      planned_count: @occurrence_count,
      interval_kind: @interval_kind,
      interval_days: @interval_kind == 'days' ? @interval_days : nil,
      timezone: @timezone,
      started_at: @starts_at
    )
  end

  def build_appointment(series, occurrence_starts_at, occurrence_number)
    series.kanban_calendar_appointments.build(
      account: @account,
      contact: @contact,
      kanban_card: @kanban_card,
      kanban_calendar_procedure: @procedure,
      starts_at: occurrence_starts_at,
      ends_at: occurrence_ends_at(occurrence_starts_at),
      timezone: @timezone,
      occurrence_number: occurrence_number
    )
  end

  def create_resource_reservations!(appointment)
    resources.each do |resource|
      appointment.kanban_calendar_appointment_resources.create!(
        kanban_calendar_resource: resource,
        starts_at: appointment.starts_at,
        ends_at: appointment.ends_at,
        appointment_status: appointment.status
      )
    end
  end

  def create_event!(appointment)
    appointment.kanban_calendar_appointment_events.create!(
      account: @account,
      actor: @actor,
      event_type: 'created',
      occurred_at: Time.current
    )
  end
end
