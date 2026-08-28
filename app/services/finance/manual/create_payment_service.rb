class Finance::Manual::CreatePaymentService
  def initialize(connection:, contact:, **attributes)
    @connection = connection
    @contact = contact
    @amount_cents = attributes.fetch(:amount_cents)
    @billing_type = attributes.fetch(:billing_type)
    @due_on = attributes.fetch(:due_on)
    @description = attributes[:description]
    @currency = attributes.fetch(:currency)
    @kanban_card = attributes[:kanban_card]
    @actor = attributes[:actor]
  end

  def perform
    ensure_connection_ready!

    payment = FinancePayment.create!(
      account: @connection.account,
      contact: @contact,
      kanban_card: @kanban_card,
      finance_provider_connection: @connection,
      amount_cents: @amount_cents,
      billing_type: @billing_type,
      due_on: @due_on,
      description: @description,
      currency: @currency,
      status: 'pending'
    )
    Finance::PaymentCreatedEventService.new(payment: payment, source: 'manual_create', actor: @actor).perform

    payment
  end

  private

  def ensure_connection_ready!
    return if @connection.provider == 'manual' && @connection.status == 'connected'

    raise ActiveRecord::RecordInvalid, @connection
  end
end
