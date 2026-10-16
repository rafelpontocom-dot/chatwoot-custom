<script setup>
// RAEVO (08/10, 123jpnbcb50): «Enviar também por» — a mesma primeira mensagem por
// mais caixas do mesmo tipo (ex.: duas contas de WhatsApp no WAHA). Nasce uma
// conversa por caixa: quem recebe vê dois remetentes, e as respostas voltam
// separadas. Decisão do Pedro a 08/10.
import { useI18n } from 'vue-i18n';

const props = defineProps({
  inboxes: { type: Array, default: () => [] },
});

const selected = defineModel({ type: Array, default: () => [] });

const { t } = useI18n();

const toggle = inboxId => {
  selected.value = selected.value.includes(inboxId)
    ? selected.value.filter(id => id !== inboxId)
    : [...selected.value, inboxId];
};
</script>

<template>
  <div
    data-testid="compose-extra-inboxes"
    class="flex flex-wrap items-center w-full gap-x-3 gap-y-2 px-4 pb-3"
  >
    <span class="text-sm font-medium text-n-slate-11 whitespace-nowrap">
      {{ t('COMPOSE_NEW_CONVERSATION.FORM.ALSO_SEND_VIA.LABEL') }}
    </span>
    <button
      v-for="inbox in props.inboxes"
      :key="inbox.id"
      type="button"
      :data-testid="`compose-extra-inbox-${inbox.id}`"
      :aria-pressed="selected.includes(inbox.id)"
      class="flex items-center gap-1.5 h-7 min-w-0 rounded-md px-2 text-sm outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
      :class="
        selected.includes(inbox.id)
          ? 'bg-n-alpha-2 text-n-slate-12'
          : 'border border-solid border-n-weak text-n-slate-11 hover:bg-n-alpha-1'
      "
      @click="toggle(inbox.id)"
    >
      <span
        aria-hidden="true"
        class="size-3.5 flex-shrink-0"
        :class="
          selected.includes(inbox.id) ? 'i-lucide-check' : 'i-lucide-plus'
        "
      />
      <span class="truncate">{{ inbox.label }}</span>
    </button>
  </div>
</template>
