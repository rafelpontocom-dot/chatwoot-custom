# O que pode acontecer quando uma resposta chega.
#
# Não é um construtor de fluxos: é uma lista curta e fechada do que serve a uma
# clínica. Com dez contas, um motor genérico seria construir para um cliente que
# não existe — e cada ação a mais é uma que alguém tem de perceber, configurar e
# depois desconfiar quando algo se mexe sozinho.
#
# `mode` é a escolha que o Codex não tinha: a mesma ação pode ser aplicada na
# hora ou ficar proposta para a secretaria confirmar. Numa clínica, mover uma
# oportunidade de etapa sozinho pode ser exatamente o que se quer — ou uma
# surpresa desagradável no meio de uma negociação.
module Forms::SubmissionActions
  MOVE_STAGE = 'move_stage'.freeze
  APPLY_LABEL = 'apply_label'.freeze
  NOTIFY = 'notify'.freeze
  WEBHOOK = 'webhook'.freeze

  KINDS = [MOVE_STAGE, APPLY_LABEL, NOTIFY, WEBHOOK].freeze

  AUTOMATIC = 'automatic'.freeze
  REVIEW = 'review'.freeze
  MODES = [AUTOMATIC, REVIEW].freeze

  # Um webhook não se «confirma»: quem o recebe é outro sistema, e propor a uma
  # secretária que autorize uma chamada HTTP não lhe diz nada.
  ALWAYS_AUTOMATIC = [WEBHOOK].freeze

  REQUIRED_KEYS = {
    MOVE_STAGE => %w[kanban_stage_id],
    APPLY_LABEL => %w[label],
    NOTIFY => [],
    WEBHOOK => %w[url]
  }.freeze

  module_function

  def modes_for(kind)
    ALWAYS_AUTOMATIC.include?(kind.to_s) ? [AUTOMATIC] : MODES
  end

  def supports_mode?(kind, mode)
    modes_for(kind).include?(mode.to_s)
  end

  def required_keys_for(kind)
    REQUIRED_KEYS.fetch(kind.to_s, [])
  end
end
