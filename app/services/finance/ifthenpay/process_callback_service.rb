# Handles the ifthenpay settlement callback.
#
# ifthenpay notifies by GET with query parameters and only checks the HTTP
# status of our answer, retrying up to 13 times on anything other than 200.
# Parameter names differ per payment method, so they are normalised here:
# Multibanco and MB WAY send `key`/`orderId`, Payshop sends
# `anti_phishing_key`/`order_id` and card payments send `key`/`id`.
class Finance::Ifthenpay::ProcessCallbackService
  ALLOWED_STATUS_TRANSITIONS = {
    'draft' => FinancePayment::STATUSES,
    'pending' => %w[confirmed received overdue canceled failed],
    'confirmed' => %w[received refunded canceled],
    'overdue' => %w[pending confirmed received canceled],
    'canceled' => %w[pending received],
    'failed' => %w[pending received],
    'received' => %w[refunded chargeback],
    'refunded' => [],
    'chargeback' => []
  }.freeze

  def initialize(connection:, params:)
    @connection = connection
    @params = params.to_h.with_indifferent_access
  end

  def perform
    @connection.with_lock do
      payment = find_payment!
      existing = existing_event_for(payment)
      next existing if existing.present?

      transition_allowed = ALLOWED_STATUS_TRANSITIONS.fetch(payment.status, []).include?('received') ||
                           payment.status == 'received'
      event = payment.finance_payment_events.create!(event_attributes(payment, transition_allowed))
      payment.update!(payment_attributes) if transition_allowed && payment.status != 'received'
      @connection.update!(last_webhook_at: Time.current, last_error: nil, status: 'connected')
      event
    end
  end

  def self.order_id(params)
    params = params.to_h.with_indifferent_access
    params[:orderId].presence || params[:order_id].presence || params[:id].presence
  end

  def self.anti_phishing_key(params)
    params = params.to_h.with_indifferent_access
    params[:key].presence || params[:anti_phishing_key].presence
  end

  private

  def find_payment!
    order_id = self.class.order_id(@params)
    payment = @connection.finance_payments.find_by(external_reference: order_id) if order_id.present?
    payment ||= @connection.finance_payments.find_by(provider_payment_id: request_id) if request_id.present?
    return payment if payment.present?

    raise ActiveRecord::RecordNotFound, "No ifthenpay payment matches order #{order_id.inspect}"
  end

  # ifthenpay does not send an event id, so the request id plus the payment
  # keeps a retried callback from being recorded twice.
  def existing_event_for(payment)
    payment.finance_payment_events.find_by(provider_event_id: provider_event_id)
  end

  def provider_event_id
    "ifthenpay-#{request_id.presence || self.class.order_id(@params)}"
  end

  def request_id
    @params[:requestId].presence || @params[:request_id].presence
  end

  def event_attributes(payment, transition_allowed)
    {
      account: @connection.account,
      finance_provider_connection: @connection,
      provider_event_id: provider_event_id,
      event_type: 'PAYMENT_RECEIVED',
      occurred_at: occurred_at,
      metadata: @params,
      processing_status: transition_allowed ? 'processed' : 'ignored',
      error_message: transition_allowed ? nil : "Payment already in #{payment.status}"
    }
  end

  def payment_attributes
    {
      status: 'received',
      paid_at: occurred_at,
      provider_payload: @params
    }
  end

  def occurred_at
    @occurred_at ||= parsed_payment_datetime || Time.current
  end

  def parsed_payment_datetime
    raw = @params[:payment_datetime].presence
    return if raw.blank?

    Time.zone.parse(raw.to_s)
  rescue ArgumentError, TypeError
    nil
  end
end
