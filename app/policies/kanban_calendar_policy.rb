class KanbanCalendarPolicy < ApplicationPolicy
  def index?
    calendar_view?
  end

  def show?
    calendar_view?
  end

  def create?
    calendar_edit?
  end

  def update?
    calendar_edit?
  end

  def configure?
    administrator? || custom_role_permission?('calendar_configure')
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless account_user
      return scope.where(account_id: account.id) if account_user.administrator?
      return scope.none if custom_role_present? && account_user.custom_role.permissions.exclude?('calendar_view')

      scope.where(account_id: account.id)
    end

    private

    def custom_role_present?
      account_user.respond_to?(:custom_role) && account_user.custom_role.present?
    end
  end

  private

  def calendar_view?
    return false unless account_user&.administrator? || account_user&.agent?
    return true unless custom_role_present?

    custom_role_permission?('calendar_view')
  end

  def calendar_edit?
    return false unless calendar_view?
    return true if administrator?
    return true unless custom_role_present?

    custom_role_permission?('calendar_create') || custom_role_permission?('calendar_edit')
  end

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
