class Forms::ClinicalRetentionService
  BATCH_SIZE = 100

  def initialize(now: Time.current)
    @now = now
  end

  def perform!
    sensitive_templates.find_each(batch_size: BATCH_SIZE) do |template|
      discard_expired_submissions(template)
    end
  end

  private

  attr_reader :now

  def sensitive_templates
    FormTemplate.where(access_classification: 'sensitive_health')
  end

  def discard_expired_submissions(template)
    retention_days = template.clinical_retention_days
    return unless retention_days&.positive?

    expired_submissions(template, retention_days).find_each(batch_size: BATCH_SIZE) do |submission|
      discard(submission)
    end
  end

  def expired_submissions(template, retention_days)
    FormSubmission.joins(:form_template_version)
                  .where(form_template_versions: { form_template_id: template.id })
                  .where(status: 'submitted')
                  .where('form_submissions.submitted_at < ?', now - retention_days.days)
  end

  def discard(submission)
    submission.with_lock do
      next unless submission.submitted? && expired?(submission)

      submission.clinical_attachments.each(&:purge)
      submission.update!(
        status: 'discarded',
        answers: {},
        sensitive_answers_ciphertext: nil,
        metadata: {}
      )
      Forms::AccessAuditService.new(
        submission: submission,
        actor: nil,
        action: 'retention_discarded'
      ).record!
    end
  end

  def expired?(submission)
    retention_days = submission.form_template_version.form_template.clinical_retention_days
    retention_days&.positive? && submission.submitted_at < now - retention_days.days
  end
end
