import { inject, onMounted, onUnmounted, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';

// RAEVO (17/10, 123jpnbcxh4) — atalhos da seleção em massa, pedidos pelo Pedro:
// - X (ou Alt+X, que funciona também com o cursor no editor de resposta) marca
//   ou desmarca a conversa aberta. Com Alt+J / Alt+K (nativos, andam entre
//   conversas) dá para marcar uma a uma sem largar o teclado. O cartão da lista
//   não recebe foco, por isso «a conversa em foco» é a aberta.
// - Shift+clique na foto marca todas entre a última marcada e esta. A lista é
//   virtualizada (a ordem no DOM não é a da lista), por isso o intervalo vem dos
//   ids na ordem de `conversationList`, não dos elementos.
// - Esc limpa a seleção, salvo com um menu aberto (aí Esc fecha o menu).
//
// A seleção é a do `useBulkActions` nativo, que o ChatList dá por `provide`.
export function useRaevoConversationSelectionShortcuts({
  conversationList,
  selectedConversations,
  clear,
  isMenuOpen,
}) {
  const route = useRoute();
  const selectConversation = inject('selectConversation', () => {});
  const deSelectConversation = inject('deSelectConversation', () => {});

  let shiftHeld = false;
  let anchor = null;
  let ranging = false;

  const inboxOf = id =>
    conversationList.value.find(conversation => conversation.id === id)
      ?.inbox_id;

  const toggleOpenConversation = () => {
    const id = Number(route.params.conversation_id);
    if (!id) return;
    if (selectedConversations.value.includes(id)) {
      deSelectConversation(id, inboxOf(id));
    } else {
      selectConversation(id, inboxOf(id));
    }
  };

  // Escrever num campo de texto não pode limpar a seleção; a caixinha da foto
  // é um <input> também, e com o foco nela o Esc tem de funcionar.
  const isWriting = () => {
    const el = document.activeElement;
    if (!el) return false;
    if (el.isContentEditable || el.tagName === 'TEXTAREA') return true;
    return el.tagName === 'INPUT' && !['checkbox', 'radio'].includes(el.type);
  };

  useKeyboardEvents({
    KeyX: { action: toggleOpenConversation },
    // Abrir uma conversa põe o foco no editor de resposta, onde «x» é texto.
    // Alt+X funciona daí, como os outros atalhos Alt do Chatwoot.
    'Alt+KeyX': {
      action: event => {
        event.preventDefault();
        toggleOpenConversation();
      },
      allowOnFocusedInput: true,
    },
    Escape: {
      action: () => {
        if (isWriting() || isMenuOpen.value) return;
        if (selectedConversations.value.length) clear();
      },
      allowOnFocusedInput: true,
    },
  });

  // O Shift tem de ser lido no próprio clique: o cartão nativo só emite o id.
  const rememberShift = event => {
    shiftHeld = event.shiftKey;
  };
  onMounted(() => document.addEventListener('mousedown', rememberShift, true));
  onUnmounted(() =>
    document.removeEventListener('mousedown', rememberShift, true)
  );

  const selectRange = (from, to) => {
    const ids = conversationList.value.map(conversation => conversation.id);
    const [start, end] = [ids.indexOf(from), ids.indexOf(to)].sort(
      (a, b) => a - b
    );
    if (start < 0) return;
    ranging = true;
    ids.slice(start, end + 1).forEach(id => {
      if (!selectedConversations.value.includes(id)) {
        selectConversation(id, inboxOf(id));
      }
    });
  };

  watch(selectedConversations, (now, before = []) => {
    if (ranging) {
      ranging = false;
      return;
    }
    const added = now.filter(id => !before.includes(id));
    if (!now.length) {
      anchor = null;
      return;
    }
    if (added.length !== 1) return;
    const [id] = added;
    if (shiftHeld && anchor !== null && anchor !== id) selectRange(anchor, id);
    anchor = id;
  });
}
