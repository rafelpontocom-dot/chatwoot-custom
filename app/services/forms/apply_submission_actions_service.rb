# Aplica o que a clínica configurou para quando uma resposta chega — ou deixa
# proposto, se ela pediu para confirmar antes.
#
# A diferença entre os dois modos é a razão de este serviço existir. Mover uma
# oportunidade de etapa sozinho pode ser exatamente o que a clínica quer, ou uma
# surpresa no meio de uma negociação. Quem decide é a configuração, e o que
# ficar por confirmar aparece no card para a secretaria resolver.
class Forms::ApplySubmissionActionsService
  def initialize(submission:)
    @submission = submission
  end

  def perform
    return if actions.blank?
    # A mesma regra do mapeamento: uma resposta clínica não move nada sozinha.
    return if sensitive_health?
    return if kanban_card.blank?

    pendentes = actions.filter_map { |action| aplicar(action.to_h) }
    registar_pendentes(pendentes)
  end

  # Executa uma ação isolada. Público porque a secretaria, ao confirmar o que
  # ficou proposto, corre exatamente o mesmo caminho — só que mais tarde.
  def executar(action)
    case action['kind'].to_s
    when Forms::SubmissionActions::MOVE_STAGE then mover_etapa(action)
    when Forms::SubmissionActions::APPLY_LABEL then aplicar_etiqueta(action)
    when Forms::SubmissionActions::NOTIFY then notificar
    when Forms::SubmissionActions::WEBHOOK then disparar_webhook(action)
    when Forms::SubmissionActions::ATTACH_TO_HISTORY then anexar_ao_historico(action)
    end
  rescue StandardError => e
    # Uma ação que falha não pode levar a resposta do paciente com ela: a
    # resposta já está guardada, e é ela que não se pode perder.
    Rails.logger.error("[forms] submission action failed: #{e.class}")
    registar_falha(action)
  end

  private

  attr_reader :submission

  def actions
    @actions ||= submission.form_template_version.schema.to_h['submission_actions']
  end

  def sensitive_health?
    submission.form_template_version.form_template.access_classification == 'sensitive_health'
  end

  def kanban_card
    @kanban_card ||= submission.kanban_card
  end

  # Devolve a ação quando ela fica pendente, e `nil` quando foi aplicada.
  def aplicar(action)
    return action if action['mode'].to_s == Forms::SubmissionActions::REVIEW

    executar(action)
    nil
  end

  def mover_etapa(action)
    etapa = kanban_card.kanban_board.kanban_stages.find_by(id: action['kanban_stage_id'])
    return registar_falha(action) if etapa.blank?

    kanban_card.update!(kanban_stage_id: etapa.id)
  end

  # A etiqueta vive na conversa, não no card: é onde o Chatwoot as guarda e
  # onde a equipa já as vê. Sem conversa ligada, não há onde a pôr.
  def aplicar_etiqueta(action)
    conversa = kanban_card.conversation
    return registar_falha(action) if conversa.blank?

    conversa.add_labels([action['label'].to_s])
  end

  def notificar
    Forms::SubmissionEventDispatcher.new(submission: submission).dispatch
  end

  def disparar_webhook(action)
    # Sai só o que identifica, nunca resposta: o destino é outro sistema, e o
    # conteúdo clínico não atravessa a fronteira.
    payload = {
      account_id: submission.account_id,
      submission_id: submission.id,
      form_template_id: submission.form_template_version.form_template_id,
      kanban_card_id: kanban_card.id,
      contact_id: submission.contact_id
    }
    Forms::SubmissionWebhookJob.perform_later(action['url'].to_s, payload)
  end

  # Deixa na conversa o rasto de que a pessoa respondeu, para quem a atende ver
  # sem sair dali. Nota privada e sem respostas: o conteúdo pertence à ficha,
  # que tem autorização própria, e não ao histórico que a equipa toda lê.
  def anexar_ao_historico(action)
    conversa = kanban_card.conversation
    return registar_falha(action) if conversa.blank?

    Messages::MessageBuilder.new(
      nil,
      conversa,
      {
        content: I18n.t(
          'forms.submission_actions.attached_to_history',
          form_name: submission.form_template_version.form_template.name
        ),
        message_type: 'outgoing',
        private: true
      }
    ).perform
  end

  def registar_pendentes(pendentes)
    return if pendentes.empty?

    submission.update!(
      metadata: submission.metadata.to_h.merge('pending_actions' => pendentes)
    )
  end

  def registar_falha(action)
    falhas = submission.metadata.to_h['failed_actions'].to_a + [action['kind']]
    submission.update!(metadata: submission.metadata.to_h.merge('failed_actions' => falhas.uniq))
  end
end
