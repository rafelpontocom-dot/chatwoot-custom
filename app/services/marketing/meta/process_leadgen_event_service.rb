class Marketing::Meta::ProcessLeadgenEventService
  # O webhook nao traz o lead, traz um `leadgen_id`. O dado exige uma segunda
  # ida a Graph com o token da pagina.
  LEAD_FIELDS = 'id,created_time,ad_id,ad_name,adset_id,adset_name,campaign_id,campaign_name,form_id,platform,field_data'.freeze

  def initialize(delivery:, event:)
    @delivery = delivery
    @event = event.to_h.stringify_keys
  end

  def perform
    return delivery.mark_processed!(status: 'ignored') if lead_form.blank?

    lead = fetch_lead
    result = Marketing::IngestLeadService.new(
      source: lead_form, payload: payload_for(lead), touchpoint_source: 'meta_lead_ad'
    ).perform

    result.ok? ? delivery.mark_processed! : delivery.mark_processed!(status: 'ignored')
    result
  rescue Marketing::Meta::ApiError, ActiveRecord::RecordInvalid => e
    delivery.mark_failed!(e)
    lead_form&.marketing_provider_connection&.mark_attention!(e)
    nil
  end

  private

  attr_reader :delivery, :event

  def lead_form
    @lead_form ||= MarketingLeadForm.active.find_by(
      account_id: delivery.account_id, external_form_id: event['form_id']
    )
  end

  def fetch_lead
    Marketing::Meta::GraphClient.request(
      :get, "/#{event.fetch('leadgen_id')}", fields: LEAD_FIELDS, access_token: page_token
    )
  end

  def page_token
    Marketing::Meta::PageTokenService.new(
      connection: lead_form.marketing_provider_connection, page_id: lead_form.page_id
    ).token
  end

  # Respostas do formulario, mais o que so o anuncio sabe: campanha, conjunto e
  # anuncio nao sao pergunta nenhuma e por isso nao passam pelo mapeamento.
  def payload_for(lead)
    answers(lead).merge(ad_attribution(lead)).merge('idempotency_key' => event['leadgen_id'])
  end

  def answers(lead)
    raw = Array(lead['field_data']).to_h { |field| [field['name'].to_s, Array(field['values']).first] }
    mapped(raw)
  end

  def mapped(raw)
    mapping = lead_form.field_mapping.to_h
    return raw if mapping.blank?

    # A pergunta que nao foi mapeada mantem o nome que o Meta lhe deu; a lista
    # branca da atribuicao descarta depois o que nao reconhece.
    raw.transform_keys { |key| mapping.fetch(key, key).to_s }
  end

  # Origem e sub-origem tem padrao porque todo lead do Lead Ads e midia paga do
  # Meta, mas a clinica que separa campanha por origem pode dizer outra no
  # formulario — sao `select` no card, e a tela so oferece opcao do quadro.
  DEFAULT_ORIGIN = { 'origem_do_lead' => 'Mídia Paga', 'sub_origem' => '[MP] Meta' }.freeze

  def ad_attribution(lead)
    {
      'campaign' => lead['campaign_name'], 'campaign_id' => lead['campaign_id'],
      'adset' => lead['adset_name'], 'adset_id' => lead['adset_id'],
      'ad' => lead['ad_name'], 'ad_id' => lead['ad_id']
    }.merge(configured_origin).compact_blank
  end

  def configured_origin
    chosen = lead_form.crm_destination.to_h.slice('origem_do_lead', 'sub_origem').compact_blank
    DEFAULT_ORIGIN.merge(chosen)
  end
end
