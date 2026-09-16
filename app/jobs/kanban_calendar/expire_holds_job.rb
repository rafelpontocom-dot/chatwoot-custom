# Devolve os horários segurados que ninguém confirmou e cancela as consultas
# cujo pagamento não chegou no prazo.
class KanbanCalendar::ExpireHoldsJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    KanbanCalendarSlotHold.expired.delete_all

    KanbanCalendarAppointment.active.where(hold_expires_at: ..Time.current).find_each do |appointment|
      KanbanCalendar::UpdateAppointmentStatusService.new(
        appointment: appointment, action: 'cancel', cancellation_reason: 'Pagamento não confirmado no prazo'
      ).perform!
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn("[calendar] could not expire unpaid appointment #{appointment.id}: #{e.message}")
    end
  end
end
