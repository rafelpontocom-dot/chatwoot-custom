# == Schema Information
#
# Table name: kanban_automation_rule_versions
#
#  id                        :bigint           not null, primary key
#  snapshot                  :jsonb            not null
#  version_number            :integer          not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  account_id                :bigint           not null
#  kanban_automation_rule_id :bigint           not null
#
# Indexes
#
#  idx_kanban_rule_versions_unique                      (kanban_automation_rule_id,version_number) UNIQUE
#  index_kanban_automation_rule_versions_on_account_id  (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (kanban_automation_rule_id => kanban_automation_rules.id)
#
class KanbanAutomationRuleVersion < ApplicationRecord
  belongs_to :account
  belongs_to :kanban_automation_rule

  validates :version_number, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :kanban_automation_rule_id }
  validates :snapshot, presence: true
  validate :rule_belongs_to_account

  private

  def rule_belongs_to_account
    return if account.blank? || kanban_automation_rule.blank?
    return if account_id == kanban_automation_rule.account_id

    errors.add(:kanban_automation_rule, :invalid)
  end
end
