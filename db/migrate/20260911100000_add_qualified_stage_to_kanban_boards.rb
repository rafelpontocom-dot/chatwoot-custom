class AddQualifiedStageToKanbanBoards < ActiveRecord::Migration[7.1]
  # Qual etapa deste funil significa "oportunidade qualificada".
  #
  # O painel da Elis mostra a jornada — conversa, oportunidade, qualificada,
  # pré-agendada, agendada — e "qualificada" era a única sem definição possível:
  # `kanban_stages.category` só conhece `open`, `won` e `lost`.
  #
  # Não dá para cravar no código porque cada clínica nomeia o funil à sua
  # maneira. Fica por quadro, e nulo significa "ainda não escolheram": o painel
  # mostra que falta configurar em vez de inventar um número.
  def change
    add_reference :kanban_boards, :qualified_stage, null: true, foreign_key: { to_table: :kanban_stages }
  end
end
