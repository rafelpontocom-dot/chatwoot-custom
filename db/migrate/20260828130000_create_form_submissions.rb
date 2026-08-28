class CreateFormSubmissions < ActiveRecord::Migration[7.1]
  def change
    create_table :form_submissions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :form_template_version, null: false, foreign_key: true
      t.references :form_invitation, foreign_key: true
      t.references :contact, foreign_key: true
      t.references :kanban_card, foreign_key: true
      t.string :status, null: false, default: 'submitted'
      t.jsonb :answers, null: false, default: {}
      t.jsonb :metadata, null: false, default: {}
      t.datetime :submitted_at, null: false
      t.timestamps
    end

    add_index :form_submissions, %i[account_id status submitted_at]
    add_index :form_submissions, %i[form_invitation_id created_at]
  end
end
