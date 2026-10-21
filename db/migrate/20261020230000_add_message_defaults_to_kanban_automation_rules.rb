class AddMessageDefaultsToKanbanAutomationRules < ActiveRecord::Migration[7.1]
  # As regras de envio de mensagem — horário silencioso, limite de frequência e
  # campo de opt-in — vivem hoje em CADA nó. Uma automação com três mensagens faz
  # as mesmas três perguntas três vezes, e as três respostas podem discordar em
  # silêncio.
  #
  # Nasce vazio de propósito: enquanto estiver vazio, nada herda e o
  # comportamento é exatamente o de hoje. A mudança só começa quando alguém
  # preencher — e aí é um gesto deliberado, não uma migração a mexer em
  # automações que já mandam mensagem a pacientes.
  def change
    add_column :kanban_automation_rules, :message_defaults, :jsonb, null: false, default: {}
  end
end
