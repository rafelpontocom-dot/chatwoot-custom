class Finance::Asaas::RefundPaymentService
  REFUNDABLE_BILLING_TYPES = %w[pix credit_card].freeze
  REFUNDABLE_STATUSES = %w[confirmed received].freeze

  def initialize(payment:, actor:, description: nil)
    @payment = payment
    @actor = actor
    @description = description
  end

  def perform
    @payment.with_lock do
      ensure_refundable!
      response = client.refund_payment(@payment.provider_payment_id, description: @description)
      record_refund_request!(response)
    end

    @payment
  end

  private

  def ensure_refundable!
    refund_already_requested! if refund_requested?
    return if asaas_payment? && @payment.status.in?(REFUNDABLE_STATUSES) &&
              @payment.billing_type.in?(REFUNDABLE_BILLING_TYPES)

    raise Finance::Asaas::ApiError, 'This charge is not eligible for an automatic refund request'
  end

  def refund_already_requested!
    @payment.errors.add(:base, 'Refund has already been requested')
    raise ActiveRecord::RecordInvalid, @payment
  end

  def asaas_payment?
    @payment.finance_provider_connection.provider == 'asaas' && @payment.provider_payment_id.present?
  end

  def refund_requested?
    @payment.finance_payment_events.exists?(event_type: 'PAYMENT_REFUND_REQUESTED')
  end

  def record_refund_request!(response)
    @payment.finance_payment_events.create!(
      account: @payment.account,
      finance_provider_connection: @payment.finance_provider_connection,
      actor: @actor,
      event_type: 'PAYMENT_REFUND_REQUESTED',
      occurred_at: Time.current,
      metadata: {
        source: 'asaas_refund_request',
        provider_response: response.slice('id', 'status')
      }
    )
  end

  def client
    @client ||= Finance::Asaas::Client.new(connection: @payment.finance_provider_connection)
  end
end
