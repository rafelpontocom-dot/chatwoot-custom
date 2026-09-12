# As duas etapas do funil que o Chatwoot sabe responder sozinho.
#
# Oportunidade criada e oportunidade qualificada são dado desta base: os
# comandos que a Elis executou estão em `raevo_ai_commands`, e os cartões
# estão no Kanban. Pedir isto à ponte seria ir buscar lá fora o que está aqui
# dentro — mais lento e dependente de ela estar de pé.
#
# As outras três etapas (conversas, pré-agendadas, agendadas) continuam a vir
# do runtime, porque a conversa e a agenda vivem lá.
class RaevoAi::FunnelMetrics
  OPPORTUNITY_COMMAND = 'crm.ensure_opportunity'.freeze
  APPLIED = 'applied'.freeze

  def initialize(integration:, window_days:)
    @integration = integration
    @window_days = window_days
  end

  def call
    { opportunities_created: opportunities_created, opportunities_qualified: opportunities_qualified }
  end

  private

  attr_reader :integration, :window_days

  def since
    @since ||= window_days.days.ago
  end

  def opportunities_created
    integration.raevo_ai_commands
               .where(command_type: OPPORTUNITY_COMMAND, state: APPLIED)
               .where(created_at: since..)
               .count
  end

  # Só sabemos a etapa actual do cartão, não por onde ele passou. Contar quem
  # está na etapa qualificada deixaria de fora tudo o que já avançou dali, e o
  # número encolheria à medida que o funil funciona — o oposto do que mede.
  # Por isso conta-se quem chegou àquela posição ou passou dela.
  #
  # `nil` e não zero quando ninguém escolheu a etapa: o painel precisa de
  # distinguir «nenhuma qualificada» de «ainda não configuraram isto».
  def opportunities_qualified
    return nil if qualified_stage.blank?

    boards_with_qualified_stage.sum do |board|
      board.kanban_cards
           .where(created_at: since..)
           .joins(:kanban_stage)
           .where(kanban_stages: { position: qualified_position(board).. })
           .count
    end
  end

  def qualified_stage
    @qualified_stage ||= boards_with_qualified_stage.first&.qualified_stage
  end

  def boards_with_qualified_stage
    # `Account` não declara `has_many :kanban_boards` — a ligação existe só do
    # lado do quadro, e é assim que o resto do produto lá chega.
    @boards_with_qualified_stage ||=
      KanbanBoard.where(account_id: integration.account_id).active.where.not(qualified_stage_id: nil).to_a
  end

  def qualified_position(board)
    board.qualified_stage.position
  end
end
