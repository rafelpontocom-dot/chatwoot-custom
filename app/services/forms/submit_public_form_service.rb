class Forms::SubmitPublicFormService
  def initialize(invitation:, answers:, metadata: {}, attachments: {})
    @invitation = invitation
    # A coerção de booleanos é do `AnswersValidator`, contra o schema. Havia
    # aqui uma segunda, com `ActiveModel::Type::Boolean`, que lia o «não» de um
    # consentimento recusado como `true` — só a string inglesa `false` a
    # convencia. Duas leituras do mesmo valor discordavam sobre um aceite.
    @answers = answers.to_h.stringify_keys
    @metadata = metadata.to_h.stringify_keys
    @attachments = attachments
  end

  def perform!
    submission = FormSubmission.transaction do
      @invitation.with_lock do
        raise_unavailable_invitation unless @invitation.available?

        submission = build_submission
        validate_answers!(submission)
        validate_attachments!(submission)
        submission.save!
        attach_clinical_documents!(submission)
        @invitation.consume!
        @invitation.form_invitation_draft&.destroy!
        submission
      end
    end

    Forms::MapSubmissionToCrmService.new(submission: submission).perform
    Forms::CreatePublicOpportunityService.new(submission: submission).perform
    # Depois de a oportunidade existir: uma ação que move etapa precisa do card.
    Forms::ApplySubmissionActionsService.new(submission: submission.reload).perform
    Forms::SubmissionEventDispatcher.new(submission: submission.reload).dispatch
    submission
  end

  private

  def build_submission
    FormSubmission.new(
      account: @invitation.account,
      form_template_version: @invitation.form_template_version,
      form_invitation: @invitation,
      contact: @invitation.contact,
      kanban_card: @invitation.kanban_card,
      metadata: @metadata,
      submitted_at: Time.current
    ).tap { |submission| submission.assign_submitted_answers(permitted_answers) }
  end

  def validate_answers!(submission)
    return if answers_validator.valid?

    answers_validator.errors.each { |error| submission.errors.add(:answers, error) }
    raise ActiveRecord::RecordInvalid, submission
  end

  def raise_unavailable_invitation
    @invitation.errors.add(:base, 'invitation is unavailable')
    raise ActiveRecord::RecordInvalid, @invitation
  end

  def permitted_answers
    @permitted_answers ||= answers_validator.permitted_answers
  end

  def answers_validator
    @answers_validator ||= Forms::AnswersValidator.new(
      schema: @invitation.form_template_version.schema,
      answers: @answers
    )
  end

  def validate_attachments!(submission)
    return if attachment_validator.valid?

    attachment_validator.errors.each { |error| submission.errors.add(:attachments, error) }
    raise ActiveRecord::RecordInvalid, submission
  end

  def attach_clinical_documents!(submission)
    return if attachment_validator.files.empty?

    submission.clinical_attachments.attach(attachment_validator.files.map { |file| attachment_attributes(file) })
  end

  def attachment_validator
    @attachment_validator ||= Forms::ClinicalAttachmentValidator.new(
      schema: @invitation.form_template_version.schema,
      answers: permitted_answers,
      attachments: @attachments
    )
  end

  def attachment_attributes(file)
    {
      io: file.tempfile,
      filename: file.original_filename,
      content_type: file.content_type
    }
  end
end
