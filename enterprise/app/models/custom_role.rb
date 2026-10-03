# == Schema Information
#
# Table name: custom_roles
#
#  id          :bigint           not null, primary key
#  description :string
#  name        :string
#  permissions :text             default([]), is an Array
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#
# Indexes
#
#  index_custom_roles_on_account_id  (account_id)
#
#

# Available permissions for custom roles:
# - 'conversation_manage': Can manage all conversations.
# - 'conversation_unassigned_manage': Can manage unassigned conversations and assign to self.
# - 'conversation_participating_manage': Can manage conversations they are participating in (assigned to or a participant).
# - 'contact_manage': Can manage contacts.
# - 'report_manage': Can manage reports.
# - 'knowledge_base_manage': Can manage knowledge base portals.
# - 'kanban_view': Can view commercial boards and opportunities.
# - 'kanban_create': Can create opportunities.
# - 'kanban_edit': Can edit opportunity data.
# - 'kanban_assign': Can change the commercial owner.
# - 'kanban_move': Can move opportunities between stages.
# - 'kanban_close': Can mark opportunities won, lost or reopened.
# - 'kanban_bulk': Can execute bulk commercial actions.
# - 'kanban_configure': Can configure commercial boards.
# - 'kanban_automate': Can create, edit, test and publish commercial automations.
# - 'kanban_automation_publish': Can publish commercial automations.
# - 'kanban_automation_test': Can safely test commercial automations.
# - 'kanban_automation_execution': Can view, retry and cancel automation executions.
# - 'kanban_manage': Can archive, restore and delete commercial boards.
# - 'kanban_report': Can view commercial reports and exports.
# - 'finance_view': Can view financial charges and their history.
# - 'finance_create': Can create payment charges.
# - 'finance_manage': Can cancel charges and confirm external payments.
# - 'finance_refund': Can request provider refunds.
# - 'finance_configure': Can configure the Finance module and providers.
# - 'marketing_view': Can see where each lead came from.
# - 'marketing_configure': Can configure the Marketing module, its connections and lead intake.

class CustomRole < ApplicationRecord
  belongs_to :account
  has_many :account_users, dependent: :nullify

  before_destroy :capture_filtered_unread_count_user_ids, prepend: true
  after_update_commit :invalidate_filtered_unread_count_visibility_update, if: :filtered_unread_count_permissions_changed?
  after_destroy_commit :invalidate_filtered_unread_count_visibility_destroy

  PERMISSIONS = %w[
    conversation_manage
    conversation_unassigned_manage
    conversation_participating_manage
    contact_manage
    report_manage
    knowledge_base_manage
    kanban_view
    kanban_create
    kanban_edit
    kanban_assign
    kanban_move
    kanban_close
    kanban_bulk
    kanban_configure
    kanban_automate
    kanban_automation_publish
    kanban_automation_test
    kanban_automation_execution
    kanban_manage
    kanban_report
    finance_view
    finance_create
    finance_manage
    finance_refund
    finance_configure
    marketing_view
    marketing_configure
  ].freeze

  validates :name, presence: true
  validates :permissions, inclusion: { in: PERMISSIONS }

  private

  def filtered_unread_count_permissions_changed?
    previous_changes.key?('permissions')
  end

  def capture_filtered_unread_count_user_ids
    @filtered_unread_count_user_ids = account_users.pluck(:user_id)
  end

  def invalidate_filtered_unread_count_visibility_update
    invalidate_filtered_unread_count_visibility(account_users.pluck(:user_id))
  end

  def invalidate_filtered_unread_count_visibility_destroy
    invalidate_filtered_unread_count_visibility(@filtered_unread_count_user_ids)
  end

  def invalidate_filtered_unread_count_visibility(user_ids)
    invalidator = ::Conversations::UnreadCounts::FilteredCountInvalidator.new(account)
    visibility_changed = invalidator.users_visibility_changed!(user_ids: user_ids)

    dispatch_account_cache_invalidated if visibility_changed
  end

  def dispatch_account_cache_invalidated
    Rails.configuration.dispatcher.dispatch(ACCOUNT_CACHE_INVALIDATED, Time.zone.now, account: account, cache_keys: account.cache_keys)
  end
end
