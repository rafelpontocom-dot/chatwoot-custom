# == Schema Information
#
# Table name: kanban_automation_executions
#
#  id                        :bigint           not null, primary key
#  action_results            :jsonb            not null
#  completed_at              :datetime
#  error_message             :text
#  event_key                 :string           not null
#  event_name                :string           not null
#  scheduled_at              :datetime
#  started_at                :datetime
#  status                    :string           default("queued"), not null
#  workflow_state            :jsonb            not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  account_id                :bigint           not null
#  kanban_automation_rule_id :bigint           not null
#  kanban_card_event_id      :bigint
#
# Indexes
#
#  idx_kanban_automation_executions_history                    (account_id,status,created_at)
#  idx_kanban_automation_executions_idempotency                (kanban_automation_rule_id,event_key) UNIQUE
#  idx_kanban_automation_executions_on_schedule                (status,scheduled_at)
#  idx_on_kanban_automation_rule_id_fc8facec2f                 (kanban_automation_rule_id)
#  index_kanban_automation_executions_on_account_id            (account_id)
#  index_kanban_automation_executions_on_kanban_card_event_id  (kanban_card_event_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (kanban_automation_rule_id => kanban_automation_rules.id)
#  fk_rails_...  (kanban_card_event_id => kanban_card_events.id)
#
class KanbanAutomationExecution < ApplicationRecord
  STATUSES = %w[queued running waiting succeeded failed skipped].freeze

  belongs_to :account
  belongs_to :kanban_automation_rule
  belongs_to :kanban_card_event, optional: true

  enum :status, STATUSES.index_by(&:itself), validate: true

  validates :event_name, :event_key, presence: true
  validates :account, :kanban_automation_rule, presence: true
  validates :event_key, uniqueness: { scope: :kanban_automation_rule_id }
  validate :rule_belongs_to_account

  private

  def rule_belongs_to_account
    return if account.blank? || kanban_automation_rule.blank?
    return if account_id == kanban_automation_rule.account_id

    errors.add(:kanban_automation_rule, :invalid)
  end
end
