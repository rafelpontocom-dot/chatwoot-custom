class Api::V1::Accounts::Forms::CardContextController < Api::V1::Accounts::BaseController
  before_action :fetch_card

  def show
    authorize FormSubmission.new(account: Current.account), :index?

    render json: {
      invitations: invitations.map { |invitation| invitation_payload(invitation) },
      submissions: submissions.map(&:summary_payload)
    }
  end

  private

  def fetch_card
    @card = KanbanCard.find_by!(account_id: Current.account.id, id: params[:kanban_card_id])
  end

  def invitations
    FormInvitation.includes(form_template_version: :form_template).where(kanban_card: @card).order(created_at: :desc)
  end

  def submissions
    FormSubmission.includes(form_template_version: :form_template).where(kanban_card: @card).order(submitted_at: :desc)
  end

  def invitation_payload(invitation)
    invitation.admin_payload.merge(form_name: invitation.form_template_version.form_template.name)
  end
end
