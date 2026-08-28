class Finance::MarkOverduePaymentsService
  BATCH_SIZE = 100
  OVERDUE_ELIGIBLE_STATUSES = %w[pending confirmed].freeze

  def initialize(now: Time.current)
    @now = now
  end

  def perform!
    overdue_payments.find_each(batch_size: BATCH_SIZE) { |payment| mark_overdue(payment) }
  end

  private

  attr_reader :now

  def overdue_payments
    FinancePayment.joins(:finance_provider_connection, account: :finance_module_setting)
                  .where(finance_module_settings: { enabled: true })
                  .where(finance_provider_connections: { provider: 'manual', status: 'connected' })
                  .where(status: OVERDUE_ELIGIBLE_STATUSES)
                  .where('finance_payments.due_on < ?', now.to_date)
  end

  def mark_overdue(payment)
    payment_event = payment.with_lock do
      next unless eligible_for_overdue?(payment)

      payment.update!(status: 'overdue')
      payment.finance_payment_events.create!(
        account: payment.account,
        finance_provider_connection: payment.finance_provider_connection,
        event_type: 'PAYMENT_OVERDUE',
        occurred_at: now,
        metadata: { source: 'automatic_due_date' }
      )
    end
    return unless payment_event

    Finance::PaymentEventDispatcher.new(payment_event: payment_event).dispatch
  end

  def eligible_for_overdue?(payment)
    payment.finance_provider_connection.provider == 'manual' &&
      payment.finance_provider_connection.status == 'connected' &&
      payment.status.in?(OVERDUE_ELIGIBLE_STATUSES) &&
      payment.due_on.present? &&
      payment.due_on < now.to_date
  end
end
