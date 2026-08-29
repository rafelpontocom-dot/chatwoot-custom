class Public::FormTemplatesController < PublicController
  before_action :fetch_form_template
  before_action :enforce_submission_rate_limit, only: :create

  def show
    respond_to do |format|
      format.html { render 'public/forms/show', layout: 'public_form' }
      format.json { render json: Forms::PublicPayloadBuilder.new(form_template: @form_template).call }
    end
  end

  def create
    return render_invalid_request if submission_params[:website].present?
    return render_invalid_request if captcha_required? && !captcha_valid?

    submission = Forms::SubmitPublicTemplateService.new(
      form_template: @form_template,
      answers: submission_params[:answers]
    ).perform!

    render json: { id: submission.id, status: submission.status, submitted_at: submission.submitted_at }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { message: e.record.errors.full_messages.to_sentence, errors: e.record.errors }, status: :unprocessable_entity
  end

  private

  def fetch_form_template
    @form_template = FormTemplate.includes(:account, active_version: :form_template).find_by(
      public_token: params[:public_token], public_enabled: true, access_classification: 'commercial'
    )
    return if @form_template&.active_version.present?

    render json: { message: 'Formulário não encontrado' }, status: :not_found
  end

  def submission_params
    params.require(:submission).permit(:website, :captcha_token, answers: {}).to_h.symbolize_keys
  end

  def captcha_required?
    @form_template.public_captcha_provider.present?
  end

  def captcha_valid?
    return false unless @form_template.public_captcha_provider == 'turnstile'

    Forms::TurnstileVerificationService.new(
      token: submission_params[:captcha_token],
      remote_ip: request.remote_ip
    ).valid?
  end

  def enforce_submission_rate_limit
    return if Forms::PublicSubmissionRateLimiter.new(scope_record: @form_template, remote_ip: request.remote_ip).allowed?

    render json: { message: 'Muitas tentativas de envio. Aguarde um minuto e tente novamente.' }, status: :too_many_requests
  end

  def render_invalid_request
    render json: { message: 'Solicitação de formulário inválida' }, status: :unprocessable_entity
  end
end
