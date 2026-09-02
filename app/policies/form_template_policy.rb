class FormTemplatePolicy < ApplicationPolicy
  def index?
    administrator?
  end

  def show?
    administrator?
  end

  def create?
    administrator?
  end

  def update?
    administrator?
  end

  def publish?
    administrator?
  end

  def duplicate?
    administrator?
  end

  # Enviar não é ler. Quem marca a consulta é quem pede a anamnese, e essa
  # pessoa é secretária, não administradora: enquanto enviar exigiu permissão
  # de administrador, o formulário ficou por enviar. O que continua fechado é a
  # resposta — ver `FormSubmissionPolicy`.
  def invite?
    record.account_id == account&.id && account_user.present?
  end

  def revoke?
    invite?
  end

  private

  def administrator?
    account_user&.administrator?
  end
end
