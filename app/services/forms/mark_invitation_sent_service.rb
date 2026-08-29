class Forms::MarkInvitationSentService
  INVITATION_TOKEN_PATTERN = %r{/formularios/convites/([A-Za-z0-9_-]{32,})}

  def initialize(message:)
    @message = message
  end

  def perform!
    return unless eligible_message?

    invitation = matching_invitation
    return if invitation.blank? || invitation.kanban_card&.conversation_id != message.conversation_id
    return unless invitation.mark_sent!

    Forms::InvitationEventDispatcher.new(invitation: invitation).dispatch_sent
  end

  private

  attr_reader :message

  def eligible_message?
    message.outgoing? && !message.private? && message.conversation_id.present?
  end

  def matching_invitation
    token = message.content.to_s[INVITATION_TOKEN_PATTERN, 1]
    return if token.blank?

    FormInvitation.includes(form_template_version: :form_template).find_by(token_digest: FormInvitation.digest_token(token))
  end
end
