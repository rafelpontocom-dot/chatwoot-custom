class CreateFormFieldGroups < ActiveRecord::Migration[7.1]
  def change
    create_table :form_field_groups do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.jsonb :section, null: false, default: {}

      t.timestamps
    end

    add_index :form_field_groups, %i[account_id name], unique: true
  end
end
