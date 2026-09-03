class Marketing::TouchpointsSummary
  # A metrica de largada honesta: quantos leads entraram sabendo de onde vieram.
  #
  # Antes de prometer ROAS, isto diz se a captacao esta funcionando. Uma taxa
  # baixa nao e um numero ruim para esconder — e a lista de anuncios que ainda
  # nao passam por um caminho que sabemos ler.
  DEFAULT_PERIOD = 30.days
  TOP_LIMIT = 5

  def initialize(account:, since: nil, until_time: nil)
    @account = account
    @since = since || DEFAULT_PERIOD.ago
    @until_time = until_time || Time.current
  end

  def perform
    {
      period: { since: since.iso8601, until: until_time.iso8601 },
      total: scope.count,
      identified: identified_count,
      capture_rate: capture_rate,
      by_origin: group_by_payload_key('origem_do_lead'),
      by_source: scope.group(:source).count,
      top_campaigns: group_by_payload_key('utm_campaign').first(TOP_LIMIT).to_h
    }
  end

  private

  attr_reader :account, :since, :until_time

  def scope
    @scope ||= account.marketing_touchpoints.where(occurred_at: since..until_time)
  end

  def identified_count
    @identified_count ||= scope.where.not(contact_id: nil).count
  end

  def capture_rate
    total = scope.count
    return 0.0 if total.zero?

    (identified_count.to_f / total * 100).round(1)
  end

  # Um toque sem a chave nao conta: contar `nil` como categoria enche o grafico
  # de "vazio" e esconde as origens reais.
  #
  # Devolve hash, nao array de pares — a tela faz `Object.entries` no resultado,
  # e um array viraria uma lista de indices numericos.
  def group_by_payload_key(key)
    scope
      .where("payload ->> :key IS NOT NULL AND payload ->> :key <> ''", key: key)
      .group(Arel.sql("payload ->> #{ActiveRecord::Base.connection.quote(key)}"))
      .count
      .sort_by { |_, count| -count }
      .to_h
  end
end
