class KanbanBoards::CommercialSummary
  # Os quatro indicadores que abrem o Pipeline no sistema aprovado. Cada um tem o
  # valor do mês corrente e o do mês anterior, porque o cartão do sistema mostra a
  # variação — e sem os dois recortes ela teria de ser inventada.
  #
  # Uma nota sobre o que NÃO está aqui. O artefacto desenha «Taxa de qualificação»,
  # e não existe qualificação no modelo: `KanbanStage::CATEGORIES` é
  # `open · won · lost` e nada mais. A métrica derivável e que se age sobre é a
  # **taxa de fecho** — ganhas sobre fechadas — e é essa que este serviço dá.
  #
  # E porque não usa o `SalesSummaryBuilder`, que já existe: aquele dá o estado de
  # AGORA com as decomposições (por etapa, por responsável, por motivo de perda) e
  # carrega os cartões todos para memória para as calcular. Este dá a dimensão que
  # falta lá — mês contra mês anterior, e o ciclo — em quatro agregações no banco,
  # sem carregar cartão nenhum. Os dois números que se sobrepõem, valor aberto e
  # contagem de ganhas, respondem a perguntas diferentes: «quanto está em jogo
  # hoje» e «quanto fechou este mês».
  def initialize(board:)
    @board = board
  end

  def call
    {
      pipeline_value: pipeline_value,
      close_rate: {
        current: close_rate(current_month), previous: close_rate(previous_month),
        closed: closed_count(current_month)
      },
      cycle_days: { current: cycle_days(current_month), previous: cycle_days(previous_month) },
      won: { current: won_totals(current_month), previous: won_totals(previous_month) },
      currency: @board.kanban_cards.pick(:amount_currency) || 'BRL'
    }
  end

  private

  def current_month
    start = Time.zone.today.beginning_of_month
    start.beginning_of_day...start.next_month.beginning_of_day
  end

  def previous_month
    start = Time.zone.today.beginning_of_month.prev_month
    start.beginning_of_day...start.next_month.beginning_of_day
  end

  # Aberta é o que não fechou nem foi arquivada. `active` sozinho não chega: um
  # cartão ganho continua ativo, e somá-lo ao funil contaria receita duas vezes.
  def open_cards
    @board.kanban_cards.where(active: true, won_at: nil, lost_at: nil, archived_at: nil)
  end

  # O valor do funil é o de AGORA, não o do mês: um cartão aberto em julho continua
  # em funil hoje. A comparação é com o que estava aberto no fim do mês anterior,
  # aproximada pelos cartões criados até lá e ainda hoje abertos — é o que a
  # tabela permite sem guardar histórico de saldo.
  def pipeline_value
    limite = Time.zone.today.beginning_of_month.beginning_of_day
    {
      current: open_cards.sum(:amount_cents),
      previous: open_cards.where(created_at: ...limite).sum(:amount_cents)
    }
  end

  # Fechadas é o denominador da taxa, e também o rodapé do cartão: uma taxa de
  # 100% sobre uma cobrança fechada não é a mesma informação que sobre trinta.
  def closed_count(range)
    @board.kanban_cards.where(won_at: range).count +
      @board.kanban_cards.where(lost_at: range).count
  end

  def close_rate(range)
    fechadas = closed_count(range)
    return nil if fechadas.zero?

    (@board.kanban_cards.where(won_at: range).count.to_f / fechadas * 100).round(1)
  end

  # Dias entre criar e ganhar, só das que ganharam no período. Em Postgres a
  # subtração de timestamps dá um interval; `EXTRACT(EPOCH …)` traz segundos, e o
  # resto é aritmética.
  def cycle_days(range)
    media = @board.kanban_cards.where(won_at: range).pick(
      Arel.sql('AVG(EXTRACT(EPOCH FROM (won_at - created_at)))')
    )
    return nil if media.nil?

    (media.to_f / 86_400).round
  end

  def won_totals(range)
    escopo = @board.kanban_cards.where(won_at: range)
    { count: escopo.count, amount_cents: escopo.sum(:amount_cents) }
  end
end
