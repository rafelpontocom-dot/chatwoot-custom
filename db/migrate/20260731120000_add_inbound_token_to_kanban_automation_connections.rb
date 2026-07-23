class AddInboundTokenToKanbanAutomationConnections < ActiveRecord::Migration[7.1]
  def change
    add_column :kanban_automation_connections, :inbound_token, :string
    add_index :kanban_automation_connections, :inbound_token, unique: true

    reversible do |direction|
      direction.up do
        KanbanAutomationConnection.reset_column_information
        KanbanAutomationConnection.where(inbound_token: nil).find_each do |connection|
          connection.update!(inbound_token: SecureRandom.urlsafe_base64(24))
        end
        change_column_null :kanban_automation_connections, :inbound_token, false
      end
    end
  end
end
