class AddAbandonedAtToFormInvitations < ActiveRecord::Migration[7.1]
  def change
    add_column :form_invitations, :abandoned_at, :datetime
    add_index :form_invitations, %i[status abandoned_at sent_at], name: 'index_form_invitations_for_abandonment'
  end
end
