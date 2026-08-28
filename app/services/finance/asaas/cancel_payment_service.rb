class Finance::Asaas::CancelPaymentService
  CANCELLABLE_STATUSES = %w[pending overdue].freeze

  def initialize(payment:, actor:)
    @payment = payment
    @actor = actor
  end

  def perform
    payment_event = @payment.with_lock do
      ensure_cancellable!
      response = client.delete_payment(@payment.provider_payment_id)

      @payment.update!(status: 'canceled')
      @payment.finance_payment_events.create!(
        account: @payment.account,
        finance_provider_connection: @payment.finance_provider_connection,
        actor: @actor,
        event_type: 'PAYMENT_DELETED',
        occurred_at: Time.current,
        metadata: { source: 'manual_cancel', provider_response: response.slice('id', 'deleted') }
      )
    end
    Finance::PaymentEventDispatcher.new(payment_event: payment_event).dispatch

    @payment
  end

  private

  def ensure_cancellable!
    return if @payment.finance_provider_connection.provider == 'asaas' &&
              @payment.provider_payment_id.present? &&
              @payment.status.in?(CANCELLABLE_STATUSES)

    raise Finance::Asaas::ApiError, 'Only pending or overdue charges can be canceled'
  end

  def client
    @client ||= Finance::Asaas::Client.new(connection: @payment.finance_provider_connection)
  end
end
