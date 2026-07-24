class AddMessageAttachmentToKanbanBirthdayAutomations < ActiveRecord::Migration[7.1]
  def change
    add_column :kanban_birthday_automations, :message_attachment, :jsonb, null: false, default: {}
  end
end
