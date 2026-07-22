class AddMessageLocaleToKanbanBirthdayAutomations < ActiveRecord::Migration[7.0]
  def change
    add_column :kanban_birthday_automations, :message_locale, :string, null: false, default: 'pt_BR'
  end
end
