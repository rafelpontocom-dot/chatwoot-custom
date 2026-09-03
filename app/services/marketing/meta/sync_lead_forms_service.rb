class Marketing::Meta::SyncLeadFormsService
  # Traz os formularios de uma pagina com as perguntas como o anunciante as
  # escreveu. E o vocabulario do Meta; o mapeamento para o CRM e escolha de
  # quem configura, e por isso nunca e sobrescrito por uma sincronizacao.
  def initialize(connection:, page_id:)
    @connection = connection
    @page_id = page_id
  end

  def perform
    fetch_forms.map { |form| store_form(form) }
  rescue Marketing::Meta::ApiError => e
    connection.mark_attention!(e)
    raise
  end

  private

  attr_reader :connection, :page_id

  def fetch_forms
    response = Marketing::Meta::GraphClient.request(
      :get, "/#{page_id}/leadgen_forms",
      fields: 'id,name,status,questions', access_token: page_token, limit: 100
    )
    Array(response['data'])
  end

  def page_token
    @page_token ||= Marketing::Meta::PageTokenService.new(connection: connection, page_id: page_id).token
  end

  def page_name
    @page_name ||= Array(connection.settings['pages']).find { |page| page['id'].to_s == page_id.to_s }&.dig('name')
  end

  def store_form(form)
    record = connection.marketing_lead_forms.find_or_initialize_by(
      account_id: connection.account_id, external_form_id: form.fetch('id')
    )
    record.assign_attributes(
      page_id: page_id, page_name: page_name, name: form['name'],
      questions: normalized_questions(form), last_synced_at: Time.current
    )
    record.save!
    record
  end

  # `key` e o nome que vem no lead; `label` e o que a pessoa leu no anuncio.
  def normalized_questions(form)
    Array(form['questions']).map do |question|
      { 'key' => question['key'].presence || question['id'], 'label' => question['label'], 'type' => question['type'] }
    end
  end
end
