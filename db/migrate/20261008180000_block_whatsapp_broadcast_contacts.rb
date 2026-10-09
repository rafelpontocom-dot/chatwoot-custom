# RAEVO (08/10, 123jpnbcb58): os contatos de status e de listas de transmissão que
# já entraram ficam bloqueados como os novos (WhatsappBroadcastContact), e as
# conversas deles que estavam abertas passam a resolvidas. `update_all` de
# propósito: sem eventos, sem webhooks, sem mensagens de atividade.
#
# Reverte-se à mão, desbloqueando o contato; a migração não guarda o estado anterior.
class BlockWhatsappBroadcastContacts < ActiveRecord::Migration[7.1]
  # rubocop:disable Rails/SkipsModelValidations
  def up
    broadcasts = Contact.where("LOWER(identifier) LIKE '%@broadcast'")
    broadcasts.update_all(blocked: true)
    Conversation.where(contact_id: broadcasts.select(:id))
                .where.not(status: Conversation.statuses[:resolved])
                .update_all(status: Conversation.statuses[:resolved])
  end
  # rubocop:enable Rails/SkipsModelValidations

  def down; end
end
