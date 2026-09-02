# O que o `settings` jsonb do formulário quer dizer, e o que nele é válido.
#
# Vive à parte porque é um assunto próprio: o `FormTemplate` trata do que é um
# formulário — versões, publicação, acesso —, e isto trata das preferências que
# a clínica lá guardou. Juntos passavam o limite de linhas da classe, e a razão
# do limite aplicava-se: eram duas coisas a partilhar um ficheiro.
module FormTemplateSettings
  extend ActiveSupport::Concern

  included do
    validate :clinical_retention_is_valid
    validate :abandonment_delay_is_valid
    validate :critical_response_is_valid
    validate :public_captcha_is_valid
    validate :answer_validity_is_valid
  end

  def clinical_retention_days
    return unless sensitive_health?

    Integer(settings&.fetch('clinical_retention_days', nil), exception: false)
  end

  def abandonment_delay_hours
    return if sensitive_health?

    Integer(settings&.fetch('abandonment_delay_hours', nil), exception: false)
  end

  def critical_response_rule
    return if sensitive_health?

    settings&.fetch('critical_response', {}).to_h.stringify_keys
  end

  # Quanto tempo a resposta continua a valer. Uma anamnese de há três anos não
  # descreve o doente que está à frente da médica, mas também não é lixo: fica,
  # marcada como vencida. Nulo é o normal — a maior parte das respostas não
  # caduca, e obrigar toda a gente a escolher um prazo seria inventar-lhe um.
  def answer_validity_days
    Integer(settings&.fetch('answer_validity_days', nil), exception: false)
  end

  # Se as respostas seguem a pessoa ou ficam na oportunidade. A anamnese segue:
  # é a mesma doente na consulta seguinte. Uma proposta comercial não segue —
  # pertence àquele negócio e a mais nenhum.
  def store_on_contact?
    ActiveModel::Type::Boolean.new.cast(settings&.fetch('store_on_contact', false)) || false
  end

  def public_captcha_provider
    settings&.fetch('captcha_provider', nil).presence
  end

  def public_captcha_site_key
    settings&.fetch('captcha_site_key', nil).to_s.strip.presence
  end

  private

  def clinical_retention_is_valid
    return unless sensitive_health?
    return if settings&.fetch('clinical_retention_days', nil).blank?
    return if clinical_retention_days.to_i.positive?

    errors.add(:settings, 'clinical retention must be at least one day')
  end

  def abandonment_delay_is_valid
    return if sensitive_health? || settings&.fetch('abandonment_delay_hours', nil).blank?
    return if abandonment_delay_hours.to_i.between?(1, 720)

    errors.add(:settings, 'abandonment delay must be between one hour and thirty days')
  end

  def critical_response_is_valid
    validator = Forms::CriticalResponseRuleValidator.new(self)
    return if validator.valid?

    validator.errors.each { |error| errors.add(:settings, error) }
  end

  def public_captcha_is_valid
    return if public_captcha_provider.blank?

    errors.add(:settings, 'captcha provider is invalid') unless public_captcha_provider == 'turnstile'
    errors.add(:settings, 'captcha site key is required') if public_captcha_site_key.blank?
  end

  def answer_validity_is_valid
    return if settings&.fetch('answer_validity_days', nil).blank?
    return if answer_validity_days.to_i.positive?

    errors.add(:settings, 'answer validity must be at least one day')
  end
end
