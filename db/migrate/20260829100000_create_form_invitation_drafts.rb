class CreateFormInvitationDrafts < ActiveRecord::Migration[7.1]
  def change
    create_table :form_invitation_drafts do |t|
      t.references :account, null: false, foreign_key: true
      t.references :form_invitation, null: false, foreign_key: true, index: { unique: true }
      t.jsonb :answers, null: false, default: {}
      t.text :sensitive_answers_ciphertext
      t.integer :current_section_index, null: false, default: 0
      t.timestamps
    end
  end
end
