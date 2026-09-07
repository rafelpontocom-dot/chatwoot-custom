# ifthenpay refunds are immediate and only available for MB WAY and card
# payments; Multibanco and Payshop have to be returned outside the gateway.
class Finance::Ifthenpay::RefundPaymentService
  REFUNDABLE_BILLING_TYPES = %w[mbway credit_card].freeze
  REFUNDABLE_STATUSES = %w[confirmed received].freeze

  def initialize(payment:, actor:, description: nil)
    @payment = payment
    @actor = actor
    @description = description
  end

  def perform
    @payment.with_lock do
      ensure_refundable!
      response = client.refund(request_id: @payment.provider_payment_id, amount: formatted_amount)
      record_refund!(response)
      @payment.update!(status: 'refunded')
    end

    @payment
  end

  private

  def ensure_refundable!
    refund_already_requested! if refund_requested?
    unless @payment.billing_type.in?(REFUNDABLE_BILLING_TYPES)
      raise Finance::Ifthenpay::ApiError,
            'ifthenpay only refunds MB WAY and card payments; Multibanco and Payshop must be returned manually'
    end
    return if ifthenpay_payment? && @payment.status.in?(REFUNDABLE_STATUSES)

    raise Finance::Ifthenpay::ApiError, 'This charge is not eligible for an automatic refund'
  end

  def refund_already_requested!
    @payment.errors.add(:base, 'Refund has already been requested')
    raise ActiveRecord::RecordInvalid, @payment
  end

  def ifthenpay_payment?
    @payment.finance_provider_connection.provider == 'ifthenpay' && @payment.provider_payment_id.present?
  end

  def refund_requested?
    @payment.finance_payment_events.exists?(event_type: 'PAYMENT_REFUND_REQUESTED')
  end

  def record_refund!(response)
    @payment.finance_payment_events.create!(
      account: @payment.account,
      finance_provider_connection: @payment.finance_provider_connection,
      actor: @actor,
      event_type: 'PAYMENT_REFUND_REQUESTED',
      occurred_at: Time.current,
      metadata: {
        source: 'ifthenpay_refund',
        description: @description,
        provider_response: response.slice('Code', 'Message')
      }
    )
  end

  def formatted_amount
    format('%.2f', @payment.amount_cents / 100.0)
  end

  def client
    @client ||= Finance::Ifthenpay::Client.new(connection: @payment.finance_provider_connection)
  end
end
