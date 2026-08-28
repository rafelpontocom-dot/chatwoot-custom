class FinanceModuleSettingPolicy < ApplicationPolicy
  def show?
    view_payments?
  end

  def update?
    configure?
  end

  def configure?
    administrator? || custom_role_permission?('finance_configure')
  end

  def view_payments?
    return false unless account_user&.administrator? || account_user&.agent?
    return true unless custom_role_present?

    custom_role_permission?('finance_view')
  end

  def create_payments?
    return false unless view_payments?
    return true unless custom_role_present?

    custom_role_permission?('finance_create')
  end

  def manage_payments?
    return false unless view_payments?
    return true unless custom_role_present?

    custom_role_permission?('finance_manage')
  end

  def refund_payments?
    administrator? || custom_role_permission?('finance_refund')
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless finance_user?
      return scope.where(account_id: account.id) if account_user.administrator?
      return scope.none unless custom_role_allows_view?

      scope.where(account_id: account.id)
    end

    private

    def custom_role_present?
      account_user.respond_to?(:custom_role) && account_user.custom_role.present?
    end

    def finance_user?
      return true if account_user&.administrator?

      account_user&.agent?
    end

    def custom_role_allows_view?
      return true unless custom_role_present?

      account_user.custom_role.permissions.include?('finance_view')
    end
  end

  private

  def administrator?
    account_user&.administrator?
  end

  def custom_role_present?
    account_user.respond_to?(:custom_role) && account_user.custom_role.present?
  end

  def custom_role_permission?(permission)
    custom_role_present? && account_user.custom_role.permissions.include?(permission)
  end
end
