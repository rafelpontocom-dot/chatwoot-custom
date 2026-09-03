class Marketing::DeriveLeadOriginService
  # Traduz a atribuicao crua para os dois campos que a equipe comercial le:
  # `origem_do_lead` e `sub_origem`.
  #
  # As duas sao `select` no preset do card, entao so podem receber valores que
  # existam nas opcoes — um valor livre fica gravado mas o campo aparece vazio
  # na tela. Por isso o que nao se reconhece cai em `[OUT] Desconhecido` em vez
  # de inventar um rotulo novo, como o fluxo do n8n faz hoje.

  PAID = 'Mídia Paga'.freeze
  ORGANIC = 'Orgânico'.freeze
  DIRECT = 'Site'.freeze
  UNKNOWN_SUB = '[OUT] Desconhecido'.freeze

  PAID_MEDIUMS = %w[cpc ppc paid paid_social paid-social cpm cpv display].freeze

  # Um id de clique e prova de anuncio mesmo sem UTM nenhuma — e e assim que a
  # maior parte do trafego pago chega quando o anunciante nao monta a URL.
  CLICK_ID_PLATFORMS = {
    'gclid' => 'google',
    'gbraid' => 'google',
    'wbraid' => 'google',
    'fbclid' => 'meta',
    'ttclid' => 'tiktok'
  }.freeze

  PLATFORM_ALIASES = {
    'google' => 'google', 'google-ads' => 'google', 'googleads' => 'google',
    'adwords' => 'google', 'google_ads' => 'google',
    'meta' => 'meta', 'facebook' => 'meta', 'fb' => 'meta', 'facebook_ads' => 'meta',
    'instagram' => 'instagram', 'ig' => 'instagram',
    'youtube' => 'youtube', 'yt' => 'youtube',
    'tiktok' => 'tiktok', 'tiktok_ads' => 'tiktok', 'ttk' => 'tiktok',
    'whatsapp' => 'whatsapp', 'wpp' => 'whatsapp'
  }.freeze

  PAID_SUB_ORIGINS = {
    'google' => '[MP] Google',
    'meta' => '[MP] Meta',
    'instagram' => '[MP] Meta',
    'youtube' => '[MP] YouTube',
    'tiktok' => '[MP] TikTok'
  }.freeze

  ORGANIC_SUB_ORIGINS = {
    'google' => '[ORG] Google',
    'instagram' => '[ORG] Instagram',
    'meta' => '[ORG] Facebook',
    'whatsapp' => '[ORG] WhatsApp'
  }.freeze

  def initialize(attribution)
    @attribution = attribution.to_h.stringify_keys
  end

  def perform
    return { 'origem_do_lead' => PAID, 'sub_origem' => PAID_SUB_ORIGINS.fetch(platform, UNKNOWN_SUB) } if paid?
    return { 'origem_do_lead' => ORGANIC, 'sub_origem' => ORGANIC_SUB_ORIGINS.fetch(platform, UNKNOWN_SUB) } if source.present?
    return { 'origem_do_lead' => DIRECT, 'sub_origem' => '[ORG] Site Direto' } if landed?

    {}
  end

  private

  attr_reader :attribution

  def source
    @source ||= attribution['utm_source'].to_s.downcase.strip
  end

  def medium
    @medium ||= attribution['utm_medium'].to_s.downcase.strip
  end

  def click_id_platform
    @click_id_platform ||= CLICK_ID_PLATFORMS.find { |key, _| attribution[key].present? }&.last
  end

  def paid?
    click_id_platform.present? || PAID_MEDIUMS.include?(medium)
  end

  # A plataforma sai do id de clique quando ha um: ele nao mente, e a utm_source
  # pode vir escrita de qualquer jeito pela agencia.
  def platform
    click_id_platform || PLATFORM_ALIASES[source]
  end

  def landed?
    attribution['landing_page'].present? || attribution['referrer'].present?
  end
end
