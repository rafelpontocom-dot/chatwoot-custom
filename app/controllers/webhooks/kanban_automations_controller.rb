class Webhooks::KanbanAutomationsController < ActionController::API
  MAX_TIMESTAMP_SKEW = 5.minutes

  def receive
    return head :unauthorized unless valid_signature?
    return render json: { message: 'X-Chatwoot-Idempotency-Key is required' }, status: :unprocessable_entity if event_key.blank?

    KanbanAutomations::InboundWebhookService.new(
      connection: connection,
      card_id: params.require(:card_id),
      event_key: event_key
    ).perform!
    head :accepted
  rescue ActionController::ParameterMissing, ActiveRecord::RecordNotFound
    head :unprocessable_entity
  end

  private

  def connection
    @connection ||= KanbanAutomationConnection.active.find_by!(inbound_token: params[:inbound_token])
  end

  def valid_signature?
    return false if timestamp.blank? || signature.blank? || stale_timestamp?

    expected = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', connection.secret, "#{timestamp}.#{request.raw_post}")}"
    ActiveSupport::SecurityUtils.secure_compare(expected, signature)
  rescue ActiveRecord::RecordNotFound
    false
  end

  def timestamp
    @timestamp ||= request.headers['X-Chatwoot-Timestamp']
  end

  def signature
    @signature ||= request.headers['X-Chatwoot-Signature']
  end

  def event_key
    request.headers['X-Chatwoot-Idempotency-Key'].to_s.presence
  end

  def stale_timestamp?
    (Time.current.to_i - Integer(timestamp)).abs > MAX_TIMESTAMP_SKEW
  rescue ArgumentError, TypeError
    true
  end
end
