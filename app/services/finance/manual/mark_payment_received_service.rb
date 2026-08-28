class Finance::Manual::MarkPaymentReceivedService
  RECEIVABLE_STATUSES = %w[pending confirmed overdue].freeze

  def initialize(payment:, actor:)
    @payment = payment
    @actor = actor
  end

  def perform
    payment_event = nil

    @payment.with_lock do
      ensure_payment_can_be_received!
      @payment.update!(status: 'received', paid_at: Time.current)
      payment_event = @payment.finance_payment_events.create!(
        account: @payment.account,
        finance_provider_connection: @payment.finance_provider_connection,
        actor: @actor,
        event_type: 'PAYMENT_RECEIVED',
        occurred_at: @payment.paid_at,
        metadata: { source: 'manual_receipt' }
      )
    end

    Finance::PaymentEventDispatcher.new(payment_event: payment_event).dispatch
    @payment
  end

  private

  def ensure_payment_can_be_received!
    return if @payment.finance_provider_connection.provider == 'manual' && @payment.status.in?(RECEIVABLE_STATUSES)

    @payment.errors.add(:status, 'cannot be marked as received')
    raise ActiveRecord::RecordInvalid, @payment
  end
end
