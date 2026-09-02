class Api::V1::Accounts::Forms::CardContextController < Api::V1::Accounts::BaseController
  before_action :fetch_card

  def show
    authorize @card, :show?

    render json: {
      invitations: invitations.map { |invitation| invitation_payload(invitation) },
      submissions: submissions.map { |submission| submission_payload(submission) },
      contact_submissions: contact_submissions.map { |submission| submission_payload(submission) }
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
    scoped_submissions.where(kanban_card: @card).order(submitted_at: :desc)
  end

  # O que a pessoa respondeu noutras oportunidades e continua a valer para ela.
  # Só entram os formulários marcados como sendo do contacto: uma proposta
  # comercial de outro negócio não tem que aparecer aqui.
  def contact_submissions
    return FormSubmission.none if @card.contact_id.blank?

    scoped_submissions
      .where(contact_id: @card.contact_id)
      .where.not(kanban_card_id: @card.id)
      .select { |submission| submission.form_template_version.form_template.store_on_contact? }
      .sort_by(&:submitted_at)
      .reverse
  end

  def scoped_submissions
    FormSubmission.includes(form_template_version: :form_template).where(account_id: Current.account.id)
  end

  # Quem não pode abrir continua a ver que existe resposta — e é tudo o que vê.
  # Esconder a existência levava a secretária a pedir a anamnese outra vez a
  # quem já a tinha preenchido.
  def submission_payload(submission)
    return submission.summary_payload if policy(submission).show?

    submission.restricted_summary_payload
  end

  def invitation_payload(invitation)
    invitation.admin_payload.merge(form_name: invitation.form_template_version.form_template.name)
  end
end
