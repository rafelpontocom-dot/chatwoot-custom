class Whatsapp::AssignmentGreetingListener < BaseListener
  include Events::Types

  # Sends a "You are talking to <agent>" message to the customer whenever a human agent
  # takes over a WhatsApp conversation. Gated by the per-inbox toggle. The greeting message
  # is flagged to skip the per-message agent-name signature so it never double-prints the name.
  def assignee_changed(event)
    conversation, _account = extract_conversation_and_account(event)
    assignee = conversation.assignee
    return if assignee.blank?

    channel = conversation.inbox.channel
    return unless channel.is_a?(Channel::Whatsapp)
    return unless channel.assignment_greeting_enabled?

    content = channel.assignment_greeting_for(assignee)
    return if content.blank?

    Messages::MessageBuilder.new(
      assignee,
      conversation,
      { content: content, content_attributes: { skip_agent_signature: true } }
    ).perform
  end
end
