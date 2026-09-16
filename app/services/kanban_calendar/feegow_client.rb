# Leitura da agenda do Feegow. Nesta fase o Raevo só lê: nada é escrito no
# prontuário, e por isso não há aqui nenhum método que crie ou cancele consulta.
class KanbanCalendar::FeegowClient
  PAGE_SIZE = 100
  MAX_PAGES = 20

  def initialize(connection:)
    @connection = connection
  end

  def appointments(professional_id:, from:, to:)
    results = []
    MAX_PAGES.times do |page|
      content = request('/appoints/search',
                        profissional_id: professional_id,
                        data_start: feegow_date(from),
                        data_end: feegow_date(to),
                        start: page * PAGE_SIZE,
                        offset: PAGE_SIZE)
      results.concat(content)
      break if content.length < PAGE_SIZE
    end
    results
  end

  def professionals
    request('/professional/list')
  end

  def units
    request('/company/list-unity')
  end

  private

  # O Feegow fala data em dd-mm-aaaa, e é assim que a agenda dele responde.
  def feegow_date(date)
    date.strftime('%d-%m-%Y')
  end

  def request(path, params = {})
    raise KanbanCalendar::FeegowApiError, 'Feegow token is missing' if @connection.api_token.blank?

    response = Faraday.get("#{base_url}#{path}") do |request|
      request.params.update(params.compact)
      request.headers['x-access-token'] = @connection.api_token
      request.headers['Content-Type'] = 'application/json'
    end
    body = parse(response)
    raise KanbanCalendar::FeegowApiError, error_message(response, body) unless response.success?

    Array(body['content'])
  rescue Faraday::Error => e
    # Feegow fora do ar tem de chegar como erro do Feegow: é ele que a
    # importação grava na ligação e que a tela mostra, em vez de um 500.
    raise KanbanCalendar::FeegowApiError, "Feegow could not be reached (#{e.class.name.demodulize})"
  end

  def parse(response)
    JSON.parse(response.body.presence || '{}')
  rescue JSON::ParserError
    {}
  end

  def error_message(response, body)
    body['message'].presence || body['erro'].presence || "Feegow #{response.status}"
  end

  def base_url
    @connection.api_url.to_s.sub(%r{/+\z}, '')
  end
end
