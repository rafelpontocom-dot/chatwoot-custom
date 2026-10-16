<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import { useMapGetter } from 'dashboard/composables/store';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { useRaevoContactPanel } from './useRaevoContactPanel';

// RAEVO (123jpnbd3by) — o acesso ao painel do contacto sai do ícone flutuante à
// direita da conversa e passa para o topo, ao lado dos ⋮. O ícone é o mesmo de
// «Alternar layout» da lista. O copiloto, quando a conta o tem, fica aqui ao lado.
const { t } = useI18n();
const { isOpen, isCopilotOpen, toggle, toggleCopilot } = useRaevoContactPanel();

const currentAccountId = useMapGetter('getCurrentAccountId');
const isFeatureEnabledonAccount = useMapGetter(
  'accounts/isFeatureEnabledonAccount'
);
const showCopilot = computed(() =>
  isFeatureEnabledonAccount.value(currentAccountId.value, FEATURE_FLAGS.CAPTAIN)
);

const contactLabel = computed(() =>
  isOpen.value
    ? t('RAEVO_CONVERSATION.CONTACT_PANEL.HIDE')
    : t('RAEVO_CONVERSATION.CONTACT_PANEL.SHOW')
);

useKeyboardEvents({ 'Alt+KeyO': { action: toggle } });
</script>

<template>
  <div class="flex items-center gap-1">
    <Button
      v-if="showCopilot"
      v-tooltip.bottom="t('CONVERSATION.SIDEBAR.COPILOT')"
      size="sm"
      variant="ghost"
      color="slate"
      icon="i-woot-captain"
      class="rounded-md"
      :class="{ 'bg-n-alpha-2 !text-n-iris-9': isCopilotOpen }"
      data-testid="raevo-copilot-panel-toggle"
      :aria-label="t('CONVERSATION.SIDEBAR.COPILOT')"
      :aria-pressed="isCopilotOpen"
      @click="toggleCopilot"
    />
    <Button
      v-tooltip.bottom="contactLabel"
      size="sm"
      variant="ghost"
      color="slate"
      :icon="
        isOpen ? 'i-lucide-arrow-left-to-line' : 'i-lucide-arrow-right-to-line'
      "
      class="rounded-md rtl:rotate-180"
      :class="{ 'bg-n-alpha-2': isOpen }"
      data-testid="raevo-contact-panel-toggle"
      :aria-label="contactLabel"
      :aria-expanded="isOpen"
      @click="toggle"
    />
  </div>
</template>
