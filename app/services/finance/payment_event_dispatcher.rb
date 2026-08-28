class Finance::PaymentEventDispatcher
  EVENT_NAMES = {
    'PAYMENT_CREATED' => Events::Types::FINANCE_PAYMENT_CREATED,
    'PAYMENT_OVERDUE' => Events::Types::FINANCE_PAYMENT_OVERDUE,
    'PAYMENT_CONFIRMED' => Events::Types::FINANCE_PAYMENT_CONFIRMED,
    'PAYMENT_RECEIVED' => Events::Types::FINANCE_PAYMENT_RECEIVED,
    'PAYMENT_DELETED' => Events::Types::FINANCE_PAYMENT_CANCELED,
    'PAYMENT_REFUNDED' => Events::Types::FINANCE_PAYMENT_REFUNDED,
    'PAYMENT_PARTIALLY_REFUNDED' => Events::Types::FINANCE_PAYMENT_REFUNDED,
    'PAYMENT_CHARGEBACK_REQUESTED' => Events::Types::FINANCE_PAYMENT_CHARGEBACK
  }.freeze

  def initialize(payment_event:)
    @payment_event = payment_event
  end

  def dispatch
    return unless event_name && card

    Rails.configuration.dispatcher.dispatch(event_name, Time.current, event_data)
  end

  private

  def event_name
    @event_name ||= EVENT_NAMES[@payment_event.event_type]
  end

  def payment
    @payment ||= @payment_event.finance_payment
  end

  def card
    @card ||= payment.kanban_card
  end

  def event_data
    {
      account_id: payment.account_id,
      board_id: card.kanban_board_id,
      card_id: card.id,
      payment_id: payment.id,
      finance_payment_event_id: @payment_event.id,
      payment_status: payment.status,
      payment_amount_cents: payment.amount_cents,
      payment_currency: payment.currency,
      payment_paid_at: payment.paid_at&.iso8601,
      event_key: "finance-payment:#{payment.id}:event:#{@payment_event.provider_event_id || @payment_event.id}"
    }
  end
end
