class Public::FormsController < PublicController
  before_action :fetch_invitation
  before_action :enforce_submission_rate_limit, only: :create

  def show
    respond_to do |format|
      format.html { render :show, layout: 'public_form' }
      format.json { render json: form_payload }
    end
  end

  def create
    return render_invalid_request if submission_params[:website].present?

    submission = Forms::SubmitPublicFormService.new(
      invitation: @invitation,
      answers: submission_params[:answers]
    ).perform!

    render json: { id: submission.id, status: submission.status, submitted_at: submission.submitted_at }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { message: e.record.errors.full_messages.to_sentence, errors: e.record.errors }, status: :unprocessable_entity
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

  def form_payload
    Forms::PublicPayloadBuilder.new(
      form_template: @invitation.form_template_version.form_template,
      form_template_version: @invitation.form_template_version
    ).call
  end

  def render_invalid_request
    render json: { message: 'Solicitação de formulário inválida' }, status: :unprocessable_entity
  end

  def enforce_submission_rate_limit
    return if Forms::PublicSubmissionRateLimiter.new(scope_record: @invitation, remote_ip: request.remote_ip).allowed?

    render json: { message: 'Muitas tentativas de envio. Aguarde um minuto e tente novamente.' }, status: :too_many_requests
  end
end
