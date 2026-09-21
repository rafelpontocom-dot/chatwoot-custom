# Extensão do Raevo: envia o recibo de leitura do WhatsApp quando o agente abre uma
# conversa com mensagens de entrada por ler. O tipo de canal e o interruptor por caixa
# de entrada são revalidados dentro do job.
class Whatsapp::ConversationReadReceiptService
  pattr_initialize [:conversation!]

  def perform
    channel = conversation.inbox.channel
    return unless channel.is_a?(Channel::Whatsapp) && channel.mark_as_read_enabled?
    return if conversation.unread_incoming_messages.blank?

    Whatsapp::MarkMessagesReadJob.perform_later(conversation.id)
  end
end
