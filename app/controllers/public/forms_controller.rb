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

  # Um link já respondido não é um link inexistente. Quem preencheu a anamnese
  # e voltou a carregar no mesmo SMS levava «Formulário não encontrado» e
  # telefonava para a clínica a perguntar se a resposta se tinha perdido.
  def fetch_invitation
    convite = FormInvitation.includes(form_template_version: :form_template).find_by(token_digest: FormInvitation.digest_token(params[:token]))
    convite&.expire_if_needed!

    return render_invitation_state(convite) unless convite&.available? && convite.individual_public_access_allowed?

    @invitation = convite
  end

  # O paciente abre isto no telemóvel, não num cliente de API: em HTML devolve-se
  # a mesma página de marca e é ela que explica o estado. Antes caía-lhe no ecrã
  # o JSON em cru.
  def render_invitation_state(convite)
    estado = invitation_state(convite)
    codigo = estado == 'not_found' ? :not_found : :gone

    respond_to do |format|
      format.html { render 'public/forms/show', layout: 'public_form', status: codigo }
      format.json do
        render json: {
          state: estado,
          message: I18n.t("errors.forms.invitation.#{estado}"),
          form: brand_payload(convite)
        }.compact, status: codigo
      end
    end
  end

  # A marca da clínica, e só a marca. Sem isto a página de «já respondeu» saía
  # órfã, sem dizer sequer de quem era — e o schema do formulário não tem que
  # viajar para quem já não o pode preencher.
  def brand_payload(convite)
    return if convite.blank?

    template = convite.form_template_version.form_template
    {
      brand_name: template.settings['brand_name'].presence || template.account.name,
      brand_logo_url: template.brand_logo_url,
      locale: template.settings['locale'].presence || template.account.locale,
      theme: template.settings['theme'].presence || 'calm'
    }
  end

  # Um convite que existe mas não pode ser usado explica-se; um que não existe,
  # ou cujo formulário não está configurado para uso individual, cala-se — a
  # diferença entre «não existe» e «existe mas não é para si» é uma pista.
  def invitation_state(convite)
    return 'not_found' if convite.blank? || !convite.individual_public_access_allowed?

    %w[consumed expired revoked].include?(convite.status) ? convite.status : 'not_found'
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
    render json: { message: I18n.t('errors.forms.invalid_request') }, status: :unprocessable_entity
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

    render json: { message: I18n.t('errors.forms.rate_limited') }, status: :too_many_requests
  end
end
