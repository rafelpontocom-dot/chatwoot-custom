class Whatsapp::MarkMessagesReadJob < ApplicationJob
  queue_as :low

  def perform(conversation_id)
    conversation = Conversation.find_by(id: conversation_id)
    return if conversation.blank?

    channel = conversation.inbox.channel
    return unless channel.is_a?(Channel::Whatsapp)
    return unless channel.mark_as_read_enabled?

    source_id = conversation.messages.incoming.where.not(source_id: [nil, '']).last&.source_id
    return if source_id.blank?

    channel.provider_service.mark_message_as_read(source_id)
  end
end
