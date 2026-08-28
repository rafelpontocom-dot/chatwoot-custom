class Forms::SubmitPublicFormService
  def initialize(invitation:, answers:, metadata: {})
    @invitation = invitation
    @answers = answers.to_h.stringify_keys
    @metadata = metadata.to_h.stringify_keys
  end

  def perform!
    submission = FormSubmission.transaction do
      @invitation.with_lock do
        raise_unavailable_invitation unless @invitation.available?

        submission = build_submission
        validate_answers!(submission)
        submission.save!
        @invitation.consume!
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
end
