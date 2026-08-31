class Api::V1::Accounts::Forms::SubmissionsController < Api::V1::Accounts::BaseController
  before_action :fetch_submission, only: %i[show export download_attachment resolve_pending_action]

  def index
    authorize FormSubmission.new(account: Current.account), :index?

    submissions = visible_submissions.includes(:contact, :kanban_card, form_template_version: :form_template)
    submissions = submissions.order(submitted_at: :desc)
    render json: submissions.map(&:summary_payload)
  end

  def show
    authorize @form_submission
    render json: submission_payload
  end

  def download_attachment
    authorize @form_submission, :show?
    attachment = @form_submission.clinical_attachments.find(params[:attachment_id])
    Forms::AccessAuditService.new(
      submission: @form_submission,
      actor: Current.user,
      action: 'attachment_view'
    ).record!
    send_data attachment.download,
              filename: attachment.filename.to_s,
              type: attachment.content_type,
              disposition: 'attachment'
  end

  # A secretaria decide sobre o que ficou proposto pelo formulário.
  def resolve_pending_action
    authorize @form_submission, :resolve_pending_action?
    submission = Forms::ResolvePendingActionService.new(
      submission: @form_submission,
      index: params[:index],
      decision: params[:decision]
    ).perform!
    render json: { pending_actions: submission.metadata['pending_actions'] }
  rescue Forms::ResolvePendingActionService::UnknownAction
    render json: { message: I18n.t('errors.messages.invalid') }, status: :unprocessable_entity
  end

  def export
    authorize @form_submission, :export?
    Forms::AccessAuditService.new(
      submission: @form_submission,
      actor: Current.user,
      action: 'export'
    ).record!
    render json: export_payload
  end

  private

  def fetch_submission
    submissions = visible_submissions.includes(:contact, :kanban_card, form_template_version: :form_template)
    @form_submission = submissions.find(params[:id])
  end

  def visible_submissions
    policy_scope(Current.account.form_submissions)
  end

  def submission_payload
    return @form_submission.admin_payload unless @form_submission.sensitive_health_form?

    Forms::AccessAuditService.new(submission: @form_submission, actor: Current.user).record!
    payload = @form_submission.sensitive_health_payload
    return payload unless Current.account_user&.administrator?

    payload.merge(audit_trail: audit_trail)
  end

  def audit_trail
    @form_submission.form_access_audits.includes(:actor).order(occurred_at: :desc).map do |audit|
      {
        id: audit.id,
        action: audit.action,
        occurred_at: audit.occurred_at,
        actor: audit.actor && { id: audit.actor.id, name: audit.actor.name }
      }
    end
  end

  def export_payload
    payload = @form_submission.sensitive_health_form? ? @form_submission.sensitive_health_payload : @form_submission.admin_payload

    payload.except(:attachments)
  end
end
