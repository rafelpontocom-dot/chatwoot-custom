class Api::V1::Accounts::Forms::TemplateInvitationsController < Api::V1::Accounts::BaseController
  before_action :fetch_template

  def create
    authorize @form_template, :update?
    result = Forms::CreateInvitationService.new(
      account: Current.account,
      form_template_version: published_version,
      contact: invitation_contact,
      kanban_card: invitation_card,
      expires_at: invitation_params[:expires_at],
      max_uses: invitation_params.fetch(:max_uses, 1)
    ).perform

    render json: result.invitation.admin_payload.merge(token: result.token), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { message: e.record.errors.full_messages.to_sentence, errors: e.record.errors }, status: :unprocessable_entity
  end

  private

  def fetch_template
    @form_template = Current.account.form_templates.includes(:active_version).find(params[:template_id])
  end

  def published_version
    return @form_template.active_version if @form_template.active_version.present? && invitation_allowed?

    error = if @form_template.active_version.present?
              'must be eligible for an individual invitation'
            else
              'must be published before an invitation can be created'
            end
    @form_template.errors.add(:active_version, error)
    raise ActiveRecord::RecordInvalid, @form_template
  end

  def invitation_allowed?
    return true if @form_template.access_classification == 'commercial'

    @form_template.sensitive_health? && Forms::SensitiveAnswerCipher.configured?
  end

  def invitation_contact
    return if invitation_params[:contact_id].blank?

    Current.account.contacts.find(invitation_params[:contact_id])
  end

  def invitation_card
    return if invitation_params[:kanban_card_id].blank?

    Current.account.kanban_cards.find(invitation_params[:kanban_card_id])
  end

  def invitation_params
    params.require(:invitation).permit(:contact_id, :kanban_card_id, :expires_at, :max_uses)
  end
end
