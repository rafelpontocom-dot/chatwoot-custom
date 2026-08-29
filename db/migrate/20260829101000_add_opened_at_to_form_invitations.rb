class AddOpenedAtToFormInvitations < ActiveRecord::Migration[7.1]
  def change
    add_column :form_invitations, :opened_at, :datetime
  end
end
