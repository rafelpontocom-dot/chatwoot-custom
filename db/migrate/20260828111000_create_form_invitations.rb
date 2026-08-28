class CreateFormInvitations < ActiveRecord::Migration[7.1]
  def change
    create_table :form_invitations do |t|
      t.references :account, null: false, foreign_key: true
      t.references :form_template_version, null: false, foreign_key: true
      t.references :contact, foreign_key: true
      t.references :kanban_card, foreign_key: true
      t.string :token_digest, null: false
      t.string :status, null: false, default: 'active'
      t.datetime :expires_at
      t.integer :max_uses, null: false, default: 1
      t.integer :uses_count, null: false, default: 0
      t.datetime :sent_at
      t.datetime :completed_at

      t.timestamps
    end

    add_index :form_invitations, :token_digest, unique: true
    add_index :form_invitations, %i[account_id status expires_at], name: 'index_form_invitations_for_account_status'
  end
end
