class KanbanBoards::FunnelSummary
  # A Visão de funil do sistema aprovado: por etapa, quantas oportunidades
  # entraram, quantas seguiram para uma etapa à frente, e o que ficou pelo
  # caminho.
  #
  # **Porquê uma janela de 30 dias e não o mês corrente.** O resto do produto
  # compara mês contra mês anterior, porque os indicadores respondem a «como foi
  # este mês». O funil responde a outra coisa — «por onde as oportunidades
  # escorregam» — e isso é fluxo. Num dia 1 o mês corrente estaria vazio e a tela
  # não diria nada. A janela é explícita na interface, para as duas convenções não
  # se confundirem.
  #
  # **As quatro contagens, e o que cada uma quer dizer.** Não são quatro vistas do
  # mesmo número: `entered` e `advanced` são fluxo no período, `lost` é fecho no
  # período, e `open` é o estado de agora. Misturá-las numa só «perda» era o que
  # tornaria a tela enganadora: uma oportunidade que entrou e ainda está a ser
  # trabalhada não é uma perda, e somá-la às perdidas inventaria um problema.
  #
  # **O que NÃO está aqui.** A etapa em que uma oportunidade se perdeu sai de
  # `kanban_stage_id` do cartão, e não do evento: o `card_lost` guarda a data e a
  # razão, não a etapa. Se alguém mover um cartão já perdido, ele conta na etapa
  # nova. É a aproximação mais fiel que a tabela permite, e é por isso que
  # `lost` vive ao lado de `entered` em vez de ser subtraída dela.
  ENTRADA = <<~SQL.squish.freeze
    CASE event_type
      WHEN 'stage_changed' THEN (change_set -> 'kanban_stage_id' ->> 1)
      WHEN 'card_created' THEN (metadata -> 'entered_stage' ->> 'id')
    END
  SQL

  JUNTA_DESTINO = <<~SQL.squish.freeze
    INNER JOIN kanban_stages destino
      ON destino.id = (change_set -> 'kanban_stage_id' ->> 1)::bigint
  SQL

  JUNTA_ORIGEM = <<~SQL.squish.freeze
    INNER JOIN kanban_stages origem
      ON origem.id = (change_set -> 'kanban_stage_id' ->> 0)::bigint
  SQL

  JANELA_DIAS = 30

  def initialize(board:)
    @board = board
  end

  def call
    entradas = entries_by_stage
    avancos = advances_by_stage
    perdidas = lost_by_stage
    abertas = open_by_stage

    {
      window_days: JANELA_DIAS,
      stages: stages.map { |stage| row(stage, entradas, avancos, perdidas, abertas) }
    }
  end

  private

  def stages
    @stages ||= @board.kanban_stages.active.ordered.to_a
  end

  def period
    @period ||= (JANELA_DIAS.days.ago..Time.current)
  end

  def events
    KanbanCardEvent.where(kanban_board_id: @board.id, occurred_at: period)
  end

  def row(stage, entradas, avancos, perdidas, abertas)
    entered = entradas.fetch(stage.id, 0)
    advanced = avancos.fetch(stage.id, 0)

    {
      id: stage.id,
      name: stage.name,
      category: stage.category,
      entered: entered,
      advanced: advanced,
      # Sem entradas não há conversão — e zero por cento diria que ninguém
      # avançou, quando não houve ninguém para avançar.
      conversion: entered.zero? ? nil : (advanced.to_f / entered * 100).round(1),
      lost: perdidas.fetch(stage.id, 0),
      open: abertas.fetch(stage.id, 0)
    }
  end

  # Entrar numa etapa é chegar a ela: ou o cartão nasceu lá, ou foi movido para
  # lá. Os dois tipos de evento contam na mesma consulta, e não em duas somadas,
  # senão um cartão que nasceu na etapa e mais tarde voltou a ela contaria duas
  # vezes.
  def entries_by_stage
    contagem_por_id(
      events.where(event_type: %w[stage_changed card_created]).group(Arel.sql(ENTRADA))
    )
  end

  # Avançar é sair para uma etapa com posição maior. A comparação é feita no
  # banco, com as duas etapas do evento juntas por id: em Ruby, um cartão que
  # avançou duas vezes a partir da mesma etapa apareceria duas vezes.
  def advances_by_stage
    events.where(event_type: 'stage_changed')
          .joins(JUNTA_ORIGEM).joins(JUNTA_DESTINO)
          .where('destino.position > origem.position')
          .group('origem.id')
          .distinct
          .count(:kanban_card_id)
  end

  def lost_by_stage
    @board.kanban_cards.where(lost_at: period).group(:kanban_stage_id).count
  end

  def open_by_stage
    @board.kanban_cards.where(active: true, won_at: nil, lost_at: nil, archived_at: nil)
          .group(:kanban_stage_id).count
  end

  # A chave do agrupamento sai de um `CASE` sobre jsonb, logo vem como texto.
  def contagem_por_id(escopo)
    escopo.distinct.count(:kanban_card_id).each_with_object({}) do |(id, total), resultado|
      resultado[id.to_i] = total if id.present?
    end
  end
end
