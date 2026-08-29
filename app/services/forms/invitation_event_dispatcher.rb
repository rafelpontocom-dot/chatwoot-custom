class Forms::InvitationEventDispatcher
  def initialize(invitation:)
    @invitation = invitation
  end

  def dispatch_opened
    dispatch(event_name: Events::Types::FORMS_INVITATION_OPENED, event_key_suffix: 'opened')
  end

  def dispatch_sent
    dispatch(event_name: Events::Types::FORMS_INVITATION_SENT, event_key_suffix: 'sent')
  end

  def dispatch_expired(timestamp: Time.current)
    dispatch(
      event_name: Events::Types::FORMS_INVITATION_EXPIRED,
      event_key_suffix: 'expired',
      timestamp: timestamp
    )
  end

  def dispatch_abandoned(timestamp: Time.current)
    dispatch(
      event_name: Events::Types::FORMS_INVITATION_ABANDONED,
      event_key_suffix: 'abandoned',
      timestamp: timestamp
    )
  end

  private

  def dispatch(event_name:, event_key_suffix:, timestamp: Time.current)
    return if card.blank? || invitation.form_template_version.form_template.sensitive_health?

    Rails.configuration.dispatcher.dispatch(
      event_name,
      timestamp,
      event_data(event_key_suffix)
    )
  end

  attr_reader :invitation

  delegate :kanban_card, to: :invitation

  def card
    @card ||= kanban_card
  end

  def event_data(event_key_suffix)
    {
      account_id: invitation.account_id,
      board_id: card.kanban_board_id,
      card_id: card.id,
      form_invitation_id: invitation.id,
      form_template_id: invitation.form_template_version.form_template_id,
      event_key: "forms-invitation:#{invitation.id}:#{event_key_suffix}"
    }
  end
end
