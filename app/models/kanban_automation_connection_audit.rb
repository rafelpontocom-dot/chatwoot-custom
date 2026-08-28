# == Schema Information
#
# Table name: kanban_automation_connection_audits
#
#  id                              :bigint           not null, primary key
#  action                          :string           not null
#  metadata                        :jsonb            not null
#  created_at                      :datetime         not null
#  updated_at                      :datetime         not null
#  account_id                      :bigint           not null
#  actor_id                        :bigint
#  kanban_automation_connection_id :bigint
#  kanban_board_id                 :bigint           not null
#
# Indexes
#
#  idx_kanban_connection_audits_board_created                    (kanban_board_id,created_at)
#  idx_on_kanban_automation_connection_id_c72c49a724             (kanban_automation_connection_id)
#  index_kanban_automation_connection_audits_on_account_id       (account_id)
#  index_kanban_automation_connection_audits_on_actor_id         (actor_id)
#  index_kanban_automation_connection_audits_on_kanban_board_id  (kanban_board_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (actor_id => users.id)
#  fk_rails_...  (kanban_automation_connection_id => kanban_automation_connections.id)
#  fk_rails_...  (kanban_board_id => kanban_boards.id)
#
class KanbanAutomationConnectionAudit < ApplicationRecord
  ACTIONS = %w[created updated deleted secret_reset].freeze

  belongs_to :account
  belongs_to :kanban_board
  belongs_to :kanban_automation_connection, optional: true
  belongs_to :actor, class_name: 'User', optional: true

  validates :action, inclusion: { in: ACTIONS }
  validates :account, :kanban_board, presence: true
end
