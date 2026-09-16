# Pagamento confirmado pelo provedor confirma a consulta marcada na página
# pública. É o único caminho: redirecionamento do navegador não confirma nada.
class KanbanCalendarPaymentListener < BaseListener
  def finance_payment_confirmed(event)
    confirm_appointment(event)
  end

  def finance_payment_received(event)
    confirm_appointment(event)
  end

  private

  def confirm_appointment(event)
    payment_id = event.data.with_indifferent_access[:payment_id]
    return if payment_id.blank?

    KanbanCalendarAppointment.where("external_refs ->> 'finance_payment_id' = ?", payment_id.to_s)
                             .where.not(hold_expires_at: nil).find_each do |appointment|
      next unless appointment.active_for_conflict?

      appointment.update!(hold_expires_at: nil)
      KanbanCalendar::AppointmentEventDispatcher.new(appointment: appointment, event_type: 'created').dispatch
    end
  end
end
