class KanbanCardPolicy < ApplicationPolicy
  def show?
    valid_card_scope? && card_access?
  end

  def create?
    show? && can_create?
  end

  def update?
    show? && can_edit?
  end

  def destroy?
    show?
  end

  def reorder?
    show? && can_move?
  end

  def assign?
    show? && kanban_permission?('kanban_assign')
  end

  def close?
    show? && kanban_permission?('kanban_close')
  end

  def timeline?
    show?
  end

  def restore?
    !record.active? && record.archived_at.present? && valid_card_relationships? && card_access? && can_manage?
  end

  private

  def valid_card_scope?
    active_runtime_card? && valid_card_relationships?
  end

  def valid_card_relationships?
    board_runtime_available? && card_account? && board_account? && stage_account? && stage_board? && contact_account? && inbox_account?
  end

  def active_runtime_card?
    record.active? && board_runtime_available?
  end

  def board_runtime_available?
    record.kanban_board&.active? && board_visible_to_user? && record.kanban_stage&.active?
  end

  def board_visible_to_user?
    KanbanBoardPolicy.new(user_context, record.kanban_board).visible?
  end

  def card_account?
    record.account_id == account&.id
  end

  def board_account?
    record.kanban_board&.account_id == account&.id
  end

  def stage_account?
    record.kanban_stage&.account_id == account&.id
  end

  def stage_board?
    record.kanban_stage&.kanban_board_id == record.kanban_board_id
  end

  def contact_account?
    record.contact&.account_id == account&.id
  end

  def inbox_account?
    record.inbox&.account_id == account&.id
  end

  def card_access?
    record.conversation_id.present? ? conversation_card_access? : manual_card_access?
  end

  def conversation_card_access?
    valid_conversation_scope? && ConversationPolicy.new(user_context, record.conversation).show?
  end

  def valid_conversation_scope?
    record.conversation&.account_id == account&.id &&
      record.conversation&.contact_id == record.contact_id &&
      record.conversation&.inbox_id == record.inbox_id
  end

  def manual_card_access?
    administrator? || inbox_access?
  end

  def administrator?
    account_user&.administrator?
  end

  def inbox_access?
    user.inboxes.where(account_id: account&.id).exists?(id: record.inbox_id)
  end

  def can_edit?
    kanban_permission?('kanban_edit')
  end

  def can_create?
    kanban_permission?('kanban_create') || kanban_permission?('kanban_edit')
  end

  def can_move?
    kanban_permission?('kanban_move')
  end

  def can_manage?
    kanban_permission?('kanban_manage')
  end

  def kanban_permission?(permission)
    return true if administrator?
    return true unless account_user.respond_to?(:custom_role) && account_user.custom_role.present?

    account_user.custom_role.permissions.include?(permission)
  end
end
