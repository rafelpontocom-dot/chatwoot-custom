<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Avatar from 'next/avatar/Avatar.vue';
import { useUISettings } from 'dashboard/composables/useUISettings';

// RAEVO (123jpnbcxh2) — clicar no avatar do contacto, no topo da conversa, abre o
// painel do contacto. O único caminho era o ícone flutuante à direita, que
// ninguém associava ao contacto. Faz o mesmo que ele: abre ou fecha o painel e
// fecha o do copiloto.
defineProps({
  name: { type: String, default: '' },
  src: { type: String, default: '' },
  status: { type: String, default: '' },
});

const { t } = useI18n();
const { uiSettings, updateUISettings } = useUISettings();

const isOpen = computed(() =>
  Boolean(uiSettings.value.is_contact_sidebar_open)
);

const toggle = () =>
  updateUISettings({
    is_contact_sidebar_open: !isOpen.value,
    is_copilot_panel_open: false,
  });
</script>

<template>
  <button
    v-tooltip.bottom="t('RAEVO_CONVERSATION.CONTACT_PANEL.TOGGLE')"
    type="button"
    data-testid="raevo-contact-avatar-toggle"
    class="flex-shrink-0 rounded-full p-0 outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
    :aria-label="t('RAEVO_CONVERSATION.CONTACT_PANEL.TOGGLE')"
    :aria-expanded="isOpen"
    @click="toggle"
  >
    <Avatar
      :name="name"
      :src="src"
      :size="32"
      :status="status"
      hide-offline-status
    />
  </button>
</template>
