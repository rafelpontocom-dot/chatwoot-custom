<script setup>
import { useI18n } from 'vue-i18n';
import Avatar from 'next/avatar/Avatar.vue';
import { useRaevoContactPanel } from './useRaevoContactPanel';

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
const { isOpen, toggle } = useRaevoContactPanel();
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
