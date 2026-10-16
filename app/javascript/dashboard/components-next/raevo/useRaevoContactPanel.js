import { computed, watch } from 'vue';
import { useWindowSize } from '@vueuse/core';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useMapGetter } from 'dashboard/composables/store';
import wootConstants from 'dashboard/constants/globals';

// RAEVO (123jpnbd3by) — o painel do contacto e o do copiloto partilham a
// lateral direita: abrir um fecha o outro, como no botão flutuante nativo.
export function useRaevoContactPanel() {
  const { uiSettings, updateUISettings } = useUISettings();

  const isOpen = computed(() =>
    Boolean(uiSettings.value.is_contact_sidebar_open)
  );
  const isCopilotOpen = computed(() =>
    Boolean(uiSettings.value.is_copilot_panel_open)
  );

  const setOpen = open =>
    updateUISettings({
      is_contact_sidebar_open: open,
      is_copilot_panel_open: false,
    });

  const toggle = () => setOpen(!isOpen.value);

  const toggleCopilot = () =>
    updateUISettings({
      is_contact_sidebar_open: false,
      is_copilot_panel_open: !isCopilotOpen.value,
    });

  return { isOpen, isCopilotOpen, setOpen, toggle, toggleCopilot };
}

// Decisão de 16/10: abrir uma conversa abre o contacto, sempre — mesmo que a
// pessoa o tenha fechado na conversa anterior. Em telemóvel o painel cobre a
// conversa inteira, por isso aí continua a abrir só à mão.
export function useRaevoContactPanelAutoOpen(conversationId) {
  const { isOpen, setOpen } = useRaevoContactPanel();
  const { width } = useWindowSize();
  const currentUserId = useMapGetter('getCurrentUserID');

  // Só depois de o utilizador carregar: antes disso as preferências ainda vêm a
  // caminho do servidor e escreveriam «fechado» por cima do que se abriu aqui.
  const conversaPronta = computed(() =>
    currentUserId.value ? conversationId.value : null
  );

  watch(
    conversaPronta,
    id => {
      if (!id || isOpen.value) return;
      if (width.value < wootConstants.SMALL_SCREEN_BREAKPOINT) return;
      setOpen(true);
    },
    { immediate: true }
  );
}
