# A secretaria decide sobre o que ficou proposto.
#
# Uma ação em modo `review` não se aplicou sozinha: ficou registada na
# submissão à espera de alguém que conheça o caso. Aqui ela é confirmada — e
# então executada — ou descartada. Nos dois casos sai da lista, porque uma
# proposta que fica para sempre deixa de ser lida.
class Forms::ResolvePendingActionService
  class UnknownAction < StandardError; end

  CONFIRM = 'confirm'.freeze
  DISMISS = 'dismiss'.freeze
  DECISIONS = [CONFIRM, DISMISS].freeze

  def initialize(submission:, index:, decision:)
    @submission = submission
    @index = index.to_i
    @decision = decision.to_s
  end

  def perform!
    raise UnknownAction unless DECISIONS.include?(@decision)

    pendentes = pending_actions
    raise UnknownAction if @index.negative? || @index >= pendentes.length

    escolhida = pendentes[@index]
    aplicar(escolhida) if @decision == CONFIRM
    registar(pendentes, escolhida)
    @submission
  end

  private

  def pending_actions
    @submission.metadata.to_h['pending_actions'].to_a
  end

  # Confirmar executa a ação como se ela tivesse sido automática desde o início.
  def aplicar(action)
    Forms::ApplySubmissionActionsService
      .new(submission: @submission)
      .executar(action.merge('mode' => Forms::SubmissionActions::AUTOMATIC))
  end

  def registar(pendentes, escolhida)
    restantes = pendentes.reject.with_index { |_, posicao| posicao == @index }
    historico = @submission.metadata.to_h['resolved_actions'].to_a
    @submission.update!(
      metadata: @submission.metadata.to_h.merge(
        'pending_actions' => restantes,
        # Guarda quem decidiu o quê: uma etapa que se moveu sem explicação é
        # exatamente o que faz a equipa desconfiar da automação.
        'resolved_actions' => historico + [{
          'kind' => escolhida['kind'],
          'decision' => @decision,
          'actor_id' => Current.user&.id,
          'at' => Time.current.iso8601
        }]
      )
    )
  end
end
