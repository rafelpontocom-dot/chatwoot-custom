# O que o paciente resolve sozinho pelo link da consulta: remarcar e cancelar,
# dentro da política do procedimento (aba «Remarcar e cancelar»).
class KanbanCalendar::PatientChangeService
  class NotAllowed < StandardError; end

  def initialize(appointment:)
    @appointment = appointment
    @procedure = appointment.kanban_calendar_procedure
  end

  def can_reschedule?
    @procedure.reschedule_allowed? && changeable?
  end

  def can_cancel?
    @procedure.cancel_allowed? && changeable?
  end

  def reschedule!(hold)
    raise NotAllowed, 'Rescheduling is not allowed for this appointment' unless can_reschedule?
    raise NotAllowed, 'The held time belongs to another appointment' unless hold.kanban_calendar_appointment_id == @appointment.id

    ActiveRecord::Base.transaction do
      hold.lock!
      raise NotAllowed, 'The held time has expired' if hold.expired?

      hold.destroy!
      KanbanCalendar::RescheduleAppointmentService.new(
        appointment: @appointment, starts_at: hold.starts_at, resource_ids: hold.resource_ids
      ).perform!.tap { |replacement| replacement.update!(hold_token: @appointment.hold_token, booking_timezone: hold.timezone) }
    end
  end

  def cancel!(reason)
    raise NotAllowed, 'Cancelling is not allowed for this appointment' unless can_cancel?
    raise NotAllowed, 'A cancellation reason is required' if @procedure.cancel_reason_required? && reason.blank?

    canceled = KanbanCalendar::UpdateAppointmentStatusService.new(
      appointment: @appointment, action: 'cancel', cancellation_reason: reason.presence || 'Cancelada pelo paciente'
    ).perform!
    move_opportunity!
    canceled
  end

  private

  # Depois do prazo (horas antes da consulta), só a equipe muda.
  def changeable?
    @appointment.active_for_conflict? && !@appointment.externally_authoritative? &&
      Time.current <= @appointment.starts_at - @procedure.change_deadline_hours.hours
  end

  def move_opportunity!
    card = @appointment.kanban_card
    stage = target_stage(card)
    return if card.blank? || stage.blank? || card.kanban_stage_id == stage.id

    position = card.kanban_board.kanban_cards.active.where(kanban_stage: stage).maximum(:position).to_i + 1
    card.reorder_to_position!(kanban_stage: stage, position: position)
  end

  def target_stage(card)
    return if card.blank?

    case @procedure.on_cancel_stage_action
    when 'back_to_scheduling'
      page = KanbanCalendarBookingPage.find_by(account_id: @appointment.account_id)
      page&.kanban_stage if page&.kanban_board_id == card.kanban_board_id
    when 'mark_lost'
      card.kanban_board.kanban_stages.active.where(category: 'lost').order(:position).first
    end
  end
end
