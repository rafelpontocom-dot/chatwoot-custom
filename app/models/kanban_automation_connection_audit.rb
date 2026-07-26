class KanbanAutomationConnectionAudit < ApplicationRecord
  ACTIONS = %w[created updated deleted secret_reset].freeze

  belongs_to :account
  belongs_to :kanban_board
  belongs_to :kanban_automation_connection, optional: true
  belongs_to :actor, class_name: 'User', optional: true

  validates :action, inclusion: { in: ACTIONS }
  validates :account, :kanban_board, presence: true
end
