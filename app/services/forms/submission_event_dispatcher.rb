class Forms::SubmissionEventDispatcher
  def initialize(submission:)
    @submission = submission
  end

  def dispatch
    return if card.blank? || submission.sensitive_health_form?

    Rails.configuration.dispatcher.dispatch(
      Events::Types::FORMS_SUBMISSION_COMPLETED,
      Time.current,
      event_data
    )
  end

  private

  attr_reader :submission

  delegate :kanban_card, to: :submission

  def card
    @card ||= kanban_card
  end

  def event_data
    {
      account_id: submission.account_id,
      board_id: card.kanban_board_id,
      card_id: card.id,
      form_submission_id: submission.id,
      form_template_id: submission.form_template_version.form_template_id,
      event_key: "forms-submission:#{submission.id}:completed"
    }
  end
end
