# RAEVO (08/10, 123jpnbcb4w) — quem pode ser mencionado num grupo de WhatsApp.
#
# A app Chatwoot do WAHA escreve quem falou no grupo em cada mensagem:
#   👥 *Nome (123456789012628@lid)*
# no topo, ou no fim com o template «Group Participant At The Bottom». A lista sai
# daí, sem consultar o WAHA: tem quem já escreveu, não quem só lê.
#
# `mention` é o texto que o WAHA (≥ 2026.1.3, `messages/to/whatsapp/mentions.ts`)
# transforma em menção: `@<dígitos>@lid` (o sufixo sai do texto) ou `@<dígitos>`.
class WhatsappGroups::ParticipantsFromHistoryService
  PARTICIPANT = /👥 \*(?<name>[^*\n]+?) \((?<digits>\d{6,15})@(?<kind>lid|c\.us|s\.whatsapp\.net)\)\*/
  SCANNED_MESSAGES = 1000

  pattr_initialize [:conversation!]

  def perform
    return [] unless KanbanCards::ConversationEligibility.group?(conversation)

    recent_headers.each_with_object({}) do |content, participants|
      match = PARTICIPANT.match(content)
      next if match.nil? || participants.key?(match[:digits])

      participants[match[:digits]] = participant_from(match)
    end.values
  end

  private

  def recent_headers
    conversation.messages.incoming
                .where('content LIKE ?', '%👥 *%')
                .reorder(created_at: :desc, id: :desc)
                .limit(SCANNED_MESSAGES)
                .pluck(:content)
  end

  def participant_from(match)
    lid = match[:kind] == 'lid'
    {
      id: "#{match[:digits]}@#{lid ? 'lid' : 'c.us'}",
      name: match[:name].strip,
      mention: lid ? "@#{match[:digits]}@lid" : "@#{match[:digits]}"
    }
  end
end
