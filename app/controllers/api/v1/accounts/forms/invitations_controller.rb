class Api::V1::Accounts::Forms::InvitationsController < Api::V1::Accounts::BaseController
  before_action :fetch_invitation

  def revoke
    authorize @invitation.form_template_version.form_template, :update?
    @invitation.revoke!

    render json: @invitation.admin_payload
  rescue ActiveRecord::RecordInvalid => e
    render json: { message: e.record.errors.full_messages.to_sentence, errors: e.record.errors }, status: :unprocessable_entity
  end

  private

  def fetch_invitation
    @invitation = FormInvitation.find_by!(account_id: Current.account.id, id: params[:id])
  end
end
