class Forms::SubmissionEventDispatcher
  def initialize(submission:)
    @submission = submission
  end

  def dispatch
    return if card.blank? || submission.sensitive_health_form?

    dispatch_completed
    dispatch_critical_response if critical_response?
  end

  private

  attr_reader :submission

  delegate :kanban_card, to: :submission

  def dispatch_completed
    Rails.configuration.dispatcher.dispatch(
      Events::Types::FORMS_SUBMISSION_COMPLETED,
      Time.current,
      event_data('completed')
    )
  end

  def dispatch_critical_response
    Rails.configuration.dispatcher.dispatch(
      Events::Types::FORMS_SUBMISSION_CRITICAL,
      Time.current,
      event_data('critical')
    )
  end

  def critical_response?
    rule = form_template.critical_response_rule
    field_key = rule['field_key'].to_s
    return false if field_key.blank? || rule['value'].blank?

    submission.answers[field_key].to_s == rule['value'].to_s
  end

  def card
    @card ||= kanban_card
  end

  def form_template
    submission.form_template_version.form_template
  end

  def event_data(event_suffix)
    {
      account_id: submission.account_id,
      board_id: card.kanban_board_id,
      card_id: card.id,
      form_submission_id: submission.id,
      form_template_id: submission.form_template_version.form_template_id,
      event_key: "forms-submission:#{submission.id}:#{event_suffix}"
    }
  end
end
