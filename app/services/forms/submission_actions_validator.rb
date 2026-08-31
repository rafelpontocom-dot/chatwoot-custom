# Recusa publicar uma ação que o servidor não conseguiria cumprir — ou que não
# deveria cumprir.
class Forms::SubmissionActionsValidator
  HTTPS = %w[https].freeze

  attr_reader :errors

  def initialize(schema:, sensitive_health: false)
    @schema = schema.to_h
    @sensitive_health = sensitive_health
    @errors = []
    validate
  end

  private

  def actions
    @actions ||= @schema['submission_actions']
  end

  def validate
    return if actions.blank?
    return errors << 'submission actions must be a list' unless actions.is_a?(Array)

    # Anamnese não publica automação nenhuma. É a mesma regra que já impede o
    # mapeamento para CRM: uma resposta clínica não move nada sozinha.
    return errors << 'clinical forms cannot declare submission actions' if @sensitive_health

    actions.each { |action| validate_action(action.to_h) }
  end

  def validate_action(action)
    kind = action['kind'].to_s
    return errors << 'submission action must declare a supported kind' unless Forms::SubmissionActions::KINDS.include?(kind)

    validate_mode(action, kind)
    validate_required_keys(action, kind)
    validate_webhook_url(action) if kind == Forms::SubmissionActions::WEBHOOK
  end

  def validate_mode(action, kind)
    mode = action['mode'].to_s
    return if Forms::SubmissionActions.supports_mode?(kind, mode)

    errors << "submission action `#{kind}` does not support mode `#{mode}`"
  end

  def validate_required_keys(action, kind)
    faltam = Forms::SubmissionActions.required_keys_for(kind).reject { |key| action[key].present? }
    return if faltam.empty?

    errors << "submission action `#{kind}` requires #{faltam.to_sentence}"
  end

  # Só HTTPS: um webhook leva dados de paciente para fora, e em claro isso é
  # indefensável mesmo numa rede interna.
  def validate_webhook_url(action)
    uri = URI.parse(action['url'].to_s)
    return if HTTPS.include?(uri.scheme) && uri.host.present?

    errors << 'submission webhook requires an https URL'
  rescue URI::InvalidURIError
    errors << 'submission webhook requires an https URL'
  end
end
