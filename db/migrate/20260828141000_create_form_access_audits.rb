class CreateFormAccessAudits < ActiveRecord::Migration[7.1]
  def change
    create_table :form_access_audits do |t|
      t.references :account, null: false, foreign_key: true
      t.references :form_submission, null: false, foreign_key: true
      t.references :actor, foreign_key: { to_table: :users }
      t.string :action, null: false
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :form_access_audits, %i[form_submission_id occurred_at]
    add_index :form_access_audits, %i[account_id action occurred_at]
  end
end
