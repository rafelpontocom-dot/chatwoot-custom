class Marketing::UrlAttributionParser
  # Le a atribuicao que ja viaja na URL da pagina.
  #
  # O widget do Chatwoot manda a URL completa da pagina anfitria, com query
  # string, e ela e guardada em `conversation.additional_attributes['referer']`.
  # O dado sempre esteve la; nunca ninguem o leu.

  # O que o anuncio escreve na URL, no nome que o preset usa.
  # A esquerda o parametro real; a direita a chave canonica.
  QUERY_PARAM_MAP = {
    'utm_source' => 'utm_source',
    'utm_medium' => 'utm_medium',
    'utm_campaign' => 'utm_campaign',
    'utm_term' => 'utm_term',
    'utm_content' => 'utm_content',
    'utm_id' => 'utm_id',
    'utm_referrer' => 'utm_referrer',
    'gclid' => 'gclid',
    'gbraid' => 'gbraid',
    'wbraid' => 'wbraid',
    'dclid' => 'dclid',
    'msclkid' => 'msclkid',
    'fbclid' => 'fbclid',
    'ttclid' => 'ttclid',
    # nomes que as plataformas usam quando o anunciante monta a URL a mao
    'campaign_id' => 'campaign_id',
    'adset_id' => 'adset_id',
    'ad_id' => 'ad_id',
    'campaign_name' => 'campaign',
    'adset_name' => 'adset',
    'ad_name' => 'ad'
  }.freeze

  def initialize(url:, referrer: nil)
    @url = url
    @referrer = referrer
  end

  def perform
    return {} if uri.blank?

    Marketing::AttributionFields.normalize(
      query_attribution
        .merge('landing_page' => landing_page, 'landing_page_full' => @url.to_s)
        .merge(referrer.present? ? { 'referrer' => referrer } : {})
    )
  end

  private

  attr_reader :referrer

  def uri
    @uri ||= begin
      parsed = URI.parse(@url.to_s)
      parsed.is_a?(URI::HTTP) && parsed.host.present? ? parsed : nil
    rescue URI::InvalidURIError
      nil
    end
  end

  def query_attribution
    CGI.parse(uri.query.to_s).each_with_object({}) do |(param, values), memo|
      canonical = QUERY_PARAM_MAP[param.to_s.downcase]
      next if canonical.blank?

      memo[canonical] = values.first
    end
  end

  # A pagina sem a query: e o que se le num relatorio sem virar sopa de letras.
  def landing_page
    "#{uri.scheme}://#{uri.host}#{":#{uri.port}" unless uri.default_port == uri.port}#{uri.path}"
  end
end
