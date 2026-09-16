# Cobrança de uma marcação feita na página pública, pelo Financeiro da conta.
#
# A consulta nasce marcada e fica «aguardando pagamento até…» (`hold_expires_at`).
# Só o webhook do provedor a confirma (ver KanbanCalendarPaymentListener); se o
# prazo passar sem pagamento, KanbanCalendar::ExpireHoldsJob cancela e o horário volta.
# Redirecionamento do navegador nunca confirma nada.
class KanbanCalendar::BookingPaymentService
  BILLING_TYPES = { 'pix' => 'pix', 'card' => 'credit_card' }.freeze

  class PaymentUnavailable < StandardError; end

  # Pix e cartão só existem com o Financeiro ligado ao Asaas; sem ele, a página
  # oferece apenas pagar na clínica.
  def self.connection_for(account)
    setting = account.finance_module_setting
    return unless setting&.enabled && setting.default_payment_provider == 'asaas'

    account.finance_provider_connections.find_by(provider: 'asaas', status: 'connected')
  end

  def self.offered_methods(procedure)
    methods = Array(procedure.payment_methods)
    connection_for(procedure.account) ? methods : methods & %w[on_site]
  end

  def initialize(appointment:, method:, cpf:)
    @appointment = appointment
    @procedure = appointment.kanban_calendar_procedure
    @method = method
    @cpf = cpf.to_s.gsub(/\D/, '')
  end

  def online?
    @procedure.payment_enabled? && BILLING_TYPES.key?(@method)
  end

  # Pagamento online: a consulta só é anunciada quando o webhook confirmar. Se a
  # cobrança não puder ser criada, a consulta é cancelada e o erro sobe.
  def charge_or_announce!
    unless online?
      KanbanCalendar::AppointmentEventDispatcher.new(appointment: @appointment, event_type: 'created').dispatch
      return
    end

    perform!
  rescue StandardError
    cancel_unpaid! if online?
    raise
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

  def cancel_unpaid!
    KanbanCalendar::UpdateAppointmentStatusService.new(
      appointment: @appointment, action: 'cancel', cancellation_reason: 'Cobrança não pôde ser criada'
    ).perform!
  end

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
    @connection ||= self.class.connection_for(@appointment.account)
  end

  def description
    starts_at = @appointment.starts_at.in_time_zone(@appointment.timezone).strftime('%d/%m/%Y %H:%M')
    "#{@procedure.public_title.presence || @procedure.name} — #{starts_at}"
  end
end
