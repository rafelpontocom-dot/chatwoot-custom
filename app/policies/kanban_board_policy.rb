class KanbanBoardPolicy < ApplicationPolicy
  def index?
    (administrator? || agent?) && kanban_permission?('kanban_view')
  end

  def show?
    (administrator? || agent?) && kanban_permission?('kanban_view')
  end

  def create?
    (administrator? || agent?) && can_create?
  end

  def bulk?
    administrator? || kanban_permission?('kanban_bulk')
  end

  def update?
    administrator? || custom_role_permission?('kanban_configure')
  end

  def destroy?
    administrator? || custom_role_permission?('kanban_manage')
  end

  def duplicate?
    administrator? || custom_role_permission?('kanban_configure')
  end

  def archived?
    administrator? || custom_role_permission?('kanban_manage')
  end

  def restore?
    administrator? || custom_role_permission?('kanban_manage')
  end

  def report?
    administrator? || kanban_permission?('kanban_report')
  end

  def visible?
    return false unless record.is_a?(KanbanBoard)
    return false unless record.active?
    return false unless account_user
    return true if administrator?
    return false unless kanban_permission?('kanban_view')
    return true if record.visibility_mode == 'all_agents'

    record.kanban_board_members.exists?(user_id: user.id)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless account_user

      base = scope.active.where(account_id: account.id)
      return base if account_user.administrator?
      return scope.none if custom_role_present? && account_user.custom_role.permissions.exclude?('kanban_view')

      member_board_ids = KanbanBoardMember.where(user_id: user.id).select(:kanban_board_id)
      base.where(visibility_mode: 'all_agents').or(
        base.where(visibility_mode: 'selected_agents', id: member_board_ids)
      )
    end

    private

    def custom_role_present?
      account_user.respond_to?(:custom_role) && account_user.custom_role.present?
    end
  end

  private

  def administrator?
    account_user&.administrator?
  end

  def agent?
    account_user&.agent?
  end

  def kanban_permission?(permission)
    return true if administrator?
    return true unless custom_role_present?

    custom_role_permission?(permission)
  end

  def custom_role_permission?(permission)
    custom_role_present? && account_user.custom_role.permissions.include?(permission)
  end

  def can_create?
    kanban_permission?('kanban_create') || kanban_permission?('kanban_edit')
  end

  def custom_role_present?
    account_user.respond_to?(:custom_role) && account_user.custom_role.present?
  end

  def custom_role_without_permission?(permission)
    custom_role_present? && account_user.custom_role.permissions.exclude?(permission)
  end
end
