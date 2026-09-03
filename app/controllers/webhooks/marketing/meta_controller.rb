class Webhooks::Marketing::MetaController < ActionController::API
  # O Meta verifica a assinatura do webhook com o app secret, nao com um token
  # nosso no caminho: e por isso que este controller nao se parece com o do
  # Financeiro na autenticacao, so no formato de gravar-depois-processar.
  SIGNATURE_HEADER = 'X-Hub-Signature-256'.freeze

  def verify
    challenge = params['hub.challenge']
    return head :forbidden unless params['hub.mode'] == 'subscribe' && valid_verify_token?

    render plain: challenge
  end

  def receive
    return head :unauthorized unless valid_signature?

    leadgen_events.each { |event| enqueue(event) }
    # 200 sempre que a assinatura confere: o Meta reentrega em qualquer outra
    # resposta, e um formulario que nao conhecemos nao e falha nossa.
    head :ok
  end

  private

  def app_secret
    GlobalConfigService.load('MARKETING_META_APP_SECRET', nil)
  end

  def valid_verify_token?
    expected = GlobalConfigService.load('MARKETING_META_VERIFY_TOKEN', nil).to_s
    received = params['hub.verify_token'].to_s
    expected.present? && expected.bytesize == received.bytesize &&
      ActiveSupport::SecurityUtils.secure_compare(expected, received)
  end

  def valid_signature?
    received = request.headers[SIGNATURE_HEADER].to_s
    return false if app_secret.blank? || received.blank?

    expected = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', app_secret, request.raw_post)}"
    expected.bytesize == received.bytesize && ActiveSupport::SecurityUtils.secure_compare(expected, received)
  end

  # Um POST do Meta pode trazer varias paginas e varias mudancas.
  def leadgen_events
    Array(params[:entry]).flat_map do |entry|
      Array(entry[:changes]).filter_map do |change|
        next unless change[:field].to_s == 'leadgen'

        change[:value]&.permit!&.to_h
      end
    end
  end

  def enqueue(event)
    lead_form = MarketingLeadForm.active.find_by(external_form_id: event['form_id'])
    return if lead_form.blank?

    delivery = Marketing::WebhookDeliveryRecorder.new(
      account: lead_form.account, raw_payload: request.raw_post, provider_event_id: event['leadgen_id']
    ).perform
    # Assincrono: o Meta espera resposta em menos de 20s e buscar o lead e uma
    # ida a rede.
    Marketing::ProcessLeadgenEventJob.perform_later(delivery.id, event)
  end
end
