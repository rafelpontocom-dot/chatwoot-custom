# A etapa do funil que o Chatwoot sabe responder sozinho.
#
# Oportunidade criada é dado desta base: os comandos que a secretária executou
# estão em `raevo_ai_commands`. Pedir isto à ponte seria ir buscar lá fora o
# que está aqui dentro — mais lento e dependente de ela estar de pé.
#
# As outras etapas (conversas, pré-agendadas, agendadas, ganhas) vêm do
# runtime, porque a conversa, a agenda e o pagamento vivem lá.
#
# Houve aqui uma segunda etapa, «oportunidade qualificada», contada pela
# posição da etapa do quadro. Saiu porque nesta clínica qualificar e agendar
# são o mesmo momento — e porque contar por posição varria os ramos terminais
# para dentro: com a qualificadora em «Agendado», o «Perdido», que vem depois,
# entrava na contagem como qualificado.
class RaevoAi::FunnelMetrics
  OPPORTUNITY_COMMAND = 'crm.ensure_opportunity'.freeze
  APPLIED = 'applied'.freeze

  def initialize(integration:, window_days:)
    @integration = integration
    @window_days = window_days
  end

  def call
    { opportunities_created: opportunities_created }
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
end
