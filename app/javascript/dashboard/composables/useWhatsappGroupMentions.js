import { computed, ref, watch } from 'vue';
import WhatsappGroupParticipantsAPI from 'dashboard/api/whatsappGroupParticipants';

// RAEVO (08/10, 123jpnbcb4w) — o @ na resposta de um grupo de WhatsApp.
//
// O WAHA cria o grupo como contato com identificador `<id>@g.us`; é por aí que a
// conversa se reconhece como grupo, sem pedido extra. A lista vem do histórico
// (quem já escreveu); falhar a buscá-la deixa o @all, que não depende dela.
export const isWhatsappGroupConversation = conversation =>
  (conversation?.meta?.sender?.identifier || '')
    .toLowerCase()
    .endsWith('@g.us');

export function useWhatsappGroupMentions(conversation) {
  const participants = ref([]);
  const isGroup = computed(() =>
    isWhatsappGroupConversation(conversation.value)
  );

  watch(
    () => [conversation.value?.id, isGroup.value],
    async ([conversationId, group]) => {
      participants.value = [];
      if (!conversationId || !group) return;

      try {
        const { data } = await WhatsappGroupParticipantsAPI.get(conversationId);
        if (conversation.value?.id === conversationId) {
          participants.value = data.payload;
        }
      } catch {
        participants.value = [];
      }
    },
    { immediate: true }
  );

  return { isGroup, participants };
}
