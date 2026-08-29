class Forms::SubmitPublicFormService
  BOOLEAN_FIELD_TYPES = %w[checkbox consent].freeze

  def initialize(invitation:, answers:, metadata: {}, attachments: {})
    @invitation = invitation
    @answers = normalize_answers(answers)
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

  def normalize_answers(answers)
    normalized = answers.to_h.stringify_keys
    checkbox_fields.each do |field|
      key = field['key']
      normalized[key] = ActiveModel::Type::Boolean.new.cast(normalized[key]) if normalized.key?(key)
    end
    normalized
  end

  def checkbox_fields
    @invitation.form_template_version.schema.fetch('sections', []).flat_map do |section|
      section.fetch('fields', []).select { |field| BOOLEAN_FIELD_TYPES.include?(field['type']) }
    end
  end
end
