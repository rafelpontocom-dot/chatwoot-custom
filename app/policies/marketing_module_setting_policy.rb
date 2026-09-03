class MarketingModuleSettingPolicy < ApplicationPolicy
  def show?
    view?
  end

  def update?
    configure?
  end

  def configure?
    administrator? || custom_role_permission?('marketing_configure')
  end

  # Um agente comum ve a atribuicao: saber de onde o lead veio faz parte de
  # atender. So quem tem funcao personalizada precisa da permissao explicita.
  def view?
    return false unless account_user&.administrator? || account_user&.agent?
    return true unless custom_role_present?

    custom_role_permission?('marketing_view')
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless marketing_user?
      return scope.where(account_id: account.id) if account_user.administrator?
      return scope.none unless custom_role_allows_view?

      scope.where(account_id: account.id)
    end

    private

    def custom_role_present?
      account_user.respond_to?(:custom_role) && account_user.custom_role.present?
    end

    def marketing_user?
      return true if account_user&.administrator?

      account_user&.agent?
    end

    def custom_role_allows_view?
      return true unless custom_role_present?

      account_user.custom_role.permissions.include?('marketing_view')
    end
  end

  private

  def administrator?
    account_user&.administrator?
  end

  # `respond_to?` porque funcao personalizada e recurso do enterprise.
  def custom_role_present?
    account_user.respond_to?(:custom_role) && account_user.custom_role.present?
  end

  def custom_role_permission?(permission)
    custom_role_present? && account_user.custom_role.permissions.include?(permission)
  end
end
