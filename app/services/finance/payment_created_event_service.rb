class Finance::PaymentCreatedEventService
  def initialize(payment:, source:, actor: nil)
    @payment = payment
    @source = source
    @actor = actor
  end

  def perform
    payment_event = @payment.with_lock do
      @payment.finance_payment_events.create!(
        account: @payment.account,
        finance_provider_connection: @payment.finance_provider_connection,
        actor: @actor,
        event_type: 'PAYMENT_CREATED',
        occurred_at: Time.current,
        metadata: { source: @source }
      )
    end

    Finance::PaymentEventDispatcher.new(payment_event: payment_event).dispatch
    @payment
  end
end
