# ifthenpay offers no API to revoke an issued reference: a Multibanco or Payshop
# reference simply stops being payable once it expires, and an MB WAY request
# lapses on its own. Cancelling is therefore a local decision that stops the
# charge from being tracked and chased, recorded so the history stays honest.
class Finance::Ifthenpay::CancelPaymentService
  CANCELLABLE_STATUSES = %w[pending overdue].freeze

  def initialize(payment:, actor:)
    @payment = payment
    @actor = actor
  end

  def perform
    payment_event = @payment.with_lock do
      ensure_cancellable!
      @payment.update!(status: 'canceled')
      @payment.finance_payment_events.create!(
        account: @payment.account,
        finance_provider_connection: @payment.finance_provider_connection,
        actor: @actor,
        event_type: 'PAYMENT_DELETED',
        occurred_at: Time.current,
        metadata: {
          source: 'ifthenpay_local_cancel',
          note: 'ifthenpay has no revoke API; the reference is abandoned and expires on its own'
        }
      )
    end
    Finance::PaymentEventDispatcher.new(payment_event: payment_event).dispatch

    @payment
  end

  private

  def ensure_cancellable!
    return if @payment.finance_provider_connection.provider == 'ifthenpay' &&
              @payment.status.in?(CANCELLABLE_STATUSES)

    raise Finance::Ifthenpay::ApiError, 'Only pending or overdue charges can be canceled'
  end
end
