# A consulta vista pelo paciente, pelo link que recebe: o resumo do passo 3,
# o estado do pagamento e o que ele ainda pode fazer sozinho.
class KanbanCalendar::PatientBookingPayload
  def initialize(appointment:)
    @appointment = appointment
    @procedure = appointment.kanban_calendar_procedure
  end

  def call
    {
      token: @appointment.hold_token, status: status,
      starts_at: @appointment.starts_at.iso8601, ends_at: @appointment.ends_at.iso8601,
      timezone: @appointment.booking_timezone.presence || @appointment.timezone,
      procedure: procedure_payload, resources: resources_payload, clinic: clinic_payload,
      booking_page_token: page&.public_token, payment: payment
    }.merge(changes_payload)
  end

  private

  def procedure_payload
    { title: @procedure.public_title.presence || @procedure.name, duration_minutes: @procedure.duration_minutes,
      slug: @procedure.public_slug, location_type: @procedure.location_type }
  end

  def resources_payload
    @appointment.kanban_calendar_resources.order(:name).map { |resource| { name: resource.name, type: resource.resource_type } }
  end

  def clinic_payload
    page ? KanbanCalendar::PublicPagePayload.new(booking_page: page).clinic : { name: @appointment.account.name }
  end

  def changes_payload
    { can_reschedule: changes.can_reschedule?, can_cancel: changes.can_cancel?, cancel_reason_required: @procedure.cancel_reason_required }
  end

  # `awaiting_payment` enquanto o webhook não confirmar; nada mais o confirma.
  def status
    return 'canceled' unless @appointment.active_for_conflict?
    return 'awaiting_payment' if @appointment.hold_expires_at.present?

    'confirmed'
  end

  def payment
    finance_payment = finance_payment_record
    return { method: 'on_site' } if finance_payment.blank? && @procedure.payment_enabled?
    return nil if finance_payment.blank?

    {
      status: finance_payment.status,
      amount_cents: finance_payment.amount_cents,
      currency: finance_payment.currency,
      method: finance_payment.billing_type == 'credit_card' ? 'card' : finance_payment.billing_type,
      invoice_url: finance_payment.invoice_url,
      expires_at: @appointment.hold_expires_at&.iso8601
    }
  end

  def finance_payment_record
    id = @appointment.external_refs['finance_payment_id']
    id && @appointment.account.finance_payments.find_by(id: id)
  end

  def changes
    @changes ||= KanbanCalendar::PatientChangeService.new(appointment: @appointment)
  end

  def page
    @page ||= KanbanCalendarBookingPage.find_by(account_id: @appointment.account_id)
  end
end
