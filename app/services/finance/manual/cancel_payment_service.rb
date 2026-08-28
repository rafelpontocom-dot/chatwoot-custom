class Finance::Manual::CancelPaymentService
  CANCELLABLE_STATUSES = %w[pending overdue].freeze

  def initialize(payment:, actor:)
    @payment = payment
    @actor = actor
  end

  def perform
    payment_event = nil

    @payment.with_lock do
      ensure_payment_can_be_canceled!
      @payment.update!(status: 'canceled')
      payment_event = @payment.finance_payment_events.create!(
        account: @payment.account,
        finance_provider_connection: @payment.finance_provider_connection,
        actor: @actor,
        event_type: 'PAYMENT_DELETED',
        occurred_at: Time.current,
        metadata: { source: 'manual_cancel' }
      )
    end

    Finance::PaymentEventDispatcher.new(payment_event: payment_event).dispatch
    @payment
  end

  private

  def ensure_payment_can_be_canceled!
    return if @payment.finance_provider_connection.provider == 'manual' && @payment.status.in?(CANCELLABLE_STATUSES)

    @payment.errors.add(:status, 'cannot be canceled')
    raise ActiveRecord::RecordInvalid, @payment
  end
end
