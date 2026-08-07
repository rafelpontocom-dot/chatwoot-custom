class KanbanCalendar::BoardConfigurationValidator
  def initialize(card:, procedure:)
    @card = card
    @procedure = procedure
  end

  def validate!
    return unless @card
    return if calendar_enabled_for_procedure?

    @card.errors.add(:base, 'Calendar is not enabled for this funnel or procedure')
    raise ActiveRecord::RecordInvalid, @card
  end

  private

  def calendar_enabled_for_procedure?
    board.calendar_module_enabled? &&
      (board.configured_calendar_procedure_ids.empty? || @procedure.id.in?(board.configured_calendar_procedure_ids))
  end

  def board
    @card.kanban_board
  end
end
