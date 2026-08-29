class Public::FormsController < PublicController
  before_action :fetch_invitation
  before_action :enforce_submission_rate_limit, only: :create

  def show
    dispatch_opened_event if @invitation.mark_opened!

    respond_to do |format|
      format.html { render :show, layout: 'public_form' }
      format.json { render json: form_payload }
    end
  end

  def create
    return render_invalid_request if submission_params[:website].present?

    submission = Forms::SubmitPublicFormService.new(
      invitation: @invitation,
      answers: submission_params[:answers],
      attachments: submission_attachments
    ).perform!

    render json: { id: submission.id, status: submission.status, submitted_at: submission.submitted_at }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { message: e.record.errors.full_messages.to_sentence, errors: e.record.errors }, status: :unprocessable_entity
  end

  def save_draft
    payload = @invitation.with_lock do
      raise_unavailable_invitation unless @invitation.available?

      draft = @invitation.form_invitation_draft || @invitation.build_form_invitation_draft(account: @invitation.account)
      draft.assign_answers(draft_params[:answers])
      draft.assign_current_section_index(draft_params[:current_section_index])
      draft.save!
      draft.public_payload
    end

    render json: payload
  rescue ActiveRecord::RecordInvalid => e
    render json: { message: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  private

  def fetch_invitation
    @invitation = FormInvitation.includes(form_template_version: :form_template).find_available_by_token(params[:token])
    return if @invitation&.individual_public_access_allowed?

    render json: { message: 'Formulário não encontrado' }, status: :not_found
  end

  def submission_params
    params.require(:submission).permit(:website, answers: {}).to_h.symbolize_keys
  end

  def submission_attachments
    attachments = params.dig(:submission, :attachments)
    return {} if attachments.blank?
    return attachments.to_unsafe_h if attachments.respond_to?(:to_unsafe_h)

    { '_invalid' => [attachments] }
  end

  def form_payload
    Forms::PublicPayloadBuilder.new(
      form_template: @invitation.form_template_version.form_template,
      form_template_version: @invitation.form_template_version
    ).call.merge(draft: @invitation.form_invitation_draft&.public_payload)
  end

  def draft_params
    params.require(:draft).permit(:current_section_index, answers: {}).to_h.symbolize_keys
  end

  def render_invalid_request
    render json: { message: 'Solicitação de formulário inválida' }, status: :unprocessable_entity
  end

  def raise_unavailable_invitation
    @invitation.errors.add(:base, 'invitation is unavailable')
    raise ActiveRecord::RecordInvalid, @invitation
  end

  def dispatch_opened_event
    Forms::InvitationEventDispatcher.new(invitation: @invitation).dispatch_opened
  end

  def enforce_submission_rate_limit
    return if Forms::PublicSubmissionRateLimiter.new(scope_record: @invitation, remote_ip: request.remote_ip).allowed?

    render json: { message: 'Muitas tentativas de envio. Aguarde um minuto e tente novamente.' }, status: :too_many_requests
  end
end
