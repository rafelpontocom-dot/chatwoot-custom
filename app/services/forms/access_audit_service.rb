class Forms::AccessAuditService
  def initialize(submission:, actor:, action: 'view')
    @submission = submission
    @actor = actor
    @action = action
  end

  def record!
    FormAccessAudit.create!(
      account: @submission.account,
      form_submission: @submission,
      actor: @actor,
      action: @action,
      occurred_at: Time.current
    )
  end
end
