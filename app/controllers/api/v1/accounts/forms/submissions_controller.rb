class Api::V1::Accounts::Forms::SubmissionsController < Api::V1::Accounts::BaseController
  before_action :fetch_submission, only: :show

  def index
    authorize FormSubmission.new(account: Current.account), :index?

    submissions = Current.account.form_submissions.includes(:contact, :kanban_card, form_template_version: :form_template)
    submissions = submissions.order(submitted_at: :desc)
    render json: submissions.map(&:summary_payload)
  end

  def show
    authorize @form_submission
    render json: submission_payload
  end

  private

  def fetch_submission
    submissions = Current.account.form_submissions.includes(:contact, :kanban_card, form_template_version: :form_template)
    @form_submission = submissions.find(params[:id])
  end

  def submission_payload
    return @form_submission.admin_payload unless @form_submission.sensitive_health_form?

    Forms::AccessAuditService.new(submission: @form_submission, actor: Current.user).record!
    @form_submission.sensitive_health_payload
  end
end
