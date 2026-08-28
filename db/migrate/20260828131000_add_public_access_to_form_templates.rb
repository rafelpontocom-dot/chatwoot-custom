class AddPublicAccessToFormTemplates < ActiveRecord::Migration[7.1]
  def change
    add_column :form_templates, :public_enabled, :boolean, default: false, null: false
    add_column :form_templates, :public_token, :string
    add_index :form_templates, :public_token, unique: true
  end
end
