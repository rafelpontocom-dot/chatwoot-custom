# Cobrança de uma marcação feita na página pública, pelo Financeiro da conta.
#
# A consulta nasce marcada e fica «aguardando pagamento até…» (`hold_expires_at`).
# Só o webhook do provedor a confirma (ver KanbanCalendarPaymentListener); se o
# prazo passar sem pagamento, ExpireCalendarHoldsJob cancela e o horário volta.
# Redirecionamento do navegador nunca confirma nada.
class KanbanCalendar::BookingPaymentService
  BILLING_TYPES = { 'pix' => 'pix', 'card' => 'credit_card' }.freeze

  class PaymentUnavailable < StandardError; end

  def initialize(appointment:, method:, cpf:)
    @appointment = appointment
    @procedure = appointment.kanban_calendar_procedure
    @method = method
    @cpf = cpf.to_s.gsub(/\D/, '')
  end

  def online?
    @procedure.payment_enabled? && BILLING_TYPES.key?(@method)
  end

  def perform!
    return unless online?

    payment = create_payment!
    @appointment.update!(
      hold_expires_at: @procedure.hold_minutes.minutes.from_now,
      external_refs: @appointment.external_refs.merge('finance_payment_id' => payment.id)
    )
    payment
  end

  def amount_cents
    @procedure.payment_mode == 'deposit' ? @procedure.deposit_cents : @procedure.price_cents
  end

  private

  def create_payment!
    raise PaymentUnavailable, 'Online payment is not available for this clinic' if connection.blank?

    Finance::Asaas::CreatePaymentService.new(
      connection: connection,
      contact: @appointment.contact,
      kanban_card: @appointment.kanban_card,
      amount_cents: amount_cents,
      billing_type: BILLING_TYPES.fetch(@method),
      due_on: Time.current.to_date,
      cpf_cnpj: @cpf,
      description: description,
      external_reference: "calendar-appointment-#{@appointment.id}"
    ).perform
  end

  def connection
    @connection ||= begin
      setting = @appointment.account.finance_module_setting
      if setting&.enabled && setting.default_payment_provider == 'asaas'
        @appointment.account.finance_provider_connections.find_by(provider: 'asaas', status: 'connected')
      end
    end
  end

  def description
    starts_at = @appointment.starts_at.in_time_zone(@appointment.timezone).strftime('%d/%m/%Y %H:%M')
    "#{@procedure.public_title.presence || @procedure.name} — #{starts_at}"
  end
end
