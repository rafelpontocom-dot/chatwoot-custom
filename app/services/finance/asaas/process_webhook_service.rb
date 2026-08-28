class Finance::Asaas::ProcessWebhookService
  EVENT_STATUSES = {
    'PAYMENT_CREATED' => 'pending',
    'PAYMENT_AWAITING_RISK_ANALYSIS' => 'pending',
    'PAYMENT_APPROVED_BY_RISK_ANALYSIS' => 'pending',
    'PAYMENT_REPROVED_BY_RISK_ANALYSIS' => 'failed',
    'PAYMENT_AUTHORIZED' => 'pending',
    'PAYMENT_CONFIRMED' => 'confirmed',
    'PAYMENT_RECEIVED' => 'received',
    'PAYMENT_OVERDUE' => 'overdue',
    'PAYMENT_DELETED' => 'canceled',
    'PAYMENT_RESTORED' => 'pending',
    'PAYMENT_REFUNDED' => 'refunded',
    'PAYMENT_PARTIALLY_REFUNDED' => 'refunded',
    'PAYMENT_CHARGEBACK_REQUESTED' => 'chargeback'
  }.freeze
  ALLOWED_STATUS_TRANSITIONS = {
    'draft' => FinancePayment::STATUSES,
    'pending' => %w[confirmed received overdue refunded chargeback canceled failed],
    'confirmed' => %w[received overdue refunded chargeback canceled],
    'received' => %w[refunded chargeback],
    'overdue' => %w[pending confirmed received canceled],
    'canceled' => ['pending'],
    'failed' => ['pending'],
    'refunded' => [],
    'chargeback' => []
  }.freeze

  def initialize(connection:, payload:)
    @connection = connection
    @payload = payload.with_indifferent_access
  end

  def perform
    event, created = persist_event
    dispatch_event(event) if created && event.processing_status == 'processed' && dispatchable?(event)
    event
  end

  private

  def persist_event
    @connection.with_lock do
      existing_event = @connection.finance_payment_events.find_by(provider_event_id: event_id)
      next [existing_event, false] if existing_event.present?

      payment = @connection.finance_payments.find_by!(provider_payment_id: payment_payload.fetch(:id))
      transition_allowed = status_transition_allowed?(payment.status)
      event = payment.finance_payment_events.create!(payment_event_attributes(transition_allowed))
      payment.update!(payment_attributes) if transition_allowed
      @connection.update!(last_webhook_at: Time.current, last_error: nil, status: 'connected')
      [event, true]
    end
  end

  def payment_event_attributes(transition_allowed)
    {
      account: @connection.account,
      finance_provider_connection: @connection,
      provider_event_id: event_id,
      event_type: event_type,
      occurred_at: occurred_at,
      metadata: @payload,
      processing_status: transition_allowed ? 'processed' : 'ignored',
      error_message: transition_allowed ? nil : 'Outdated provider payment status'
    }
  end

  def dispatch_event(event)
    Finance::PaymentEventDispatcher.new(payment_event: event).dispatch
  end

  def event_id
    @payload.fetch(:id)
  end

  def event_type
    @payload.fetch(:event)
  end

  def payment_payload
    @payment_payload ||= @payload.fetch(:payment)
  end

  def occurred_at
    Time.zone.parse(@payload[:dateCreated].to_s) || Time.current
  end

  def payment_attributes
    {
      status: target_status,
      invoice_url: payment_payload[:invoiceUrl],
      paid_at: paid_at,
      provider_payload: payment_payload
    }.compact
  end

  def payment_status
    status = payment_payload[:status].to_s.downcase
    FinancePayment::STATUSES.include?(status) ? status : 'pending'
  end

  def target_status
    EVENT_STATUSES.fetch(event_type, payment_status)
  end

  def status_transition_allowed?(current_status)
    return true if current_status == target_status

    ALLOWED_STATUS_TRANSITIONS.fetch(current_status, []).include?(target_status)
  end

  def paid_at
    return unless EVENT_STATUSES[event_type].in?(%w[confirmed received])

    Time.zone.parse(payment_payload[:paymentDate].to_s.presence || payment_payload[:confirmedDate].to_s)
  end

  def dispatchable?(event)
    return true unless event.event_type == 'PAYMENT_CREATED'

    event.finance_payment.finance_payment_events.where(event_type: 'PAYMENT_CREATED').where.not(id: event.id).none?
  end
end
