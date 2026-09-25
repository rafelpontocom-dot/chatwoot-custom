<script setup>
import { nextTick, onBeforeUnmount, onMounted, ref } from 'vue';

defineProps({
  nodeSelected: { type: Boolean, default: false },
  ariaLabelledby: { type: String, required: true },
});

const emit = defineEmits(['close', 'focusin', 'keydown']);
const inspector = ref(null);

// Era um modal centrado de 44rem com véu por cima de toda a tela. Configurar um
// nó é decidir sobre o grafo — para onde vai cada ramo, o que o interrompe — e o
// véu apagava exatamente aquilo sobre o que se estava a decidir. É a mesma
// doença que as Configurações tiveram («um modal dentro de outro modal, e a
// lista desaparecia enquanto se editava»), e o AGENTS.md já a proíbe: a tela é a
// superfície dominante e o painel é contextual.
//
// No telemóvel continua folha com véu: aí não há espaço para os dois, e o véu
// passa a dizer a verdade. Por isso `aria-modal` acompanha — anunciá-lo modal
// com a tela clicável por trás seria mentir ao leitor de ecrã.
const CONSULTA = '(min-width: 640px)';
const ancorado = ref(true);
let consulta = null;
const sincronizar = evento => {
  ancorado.value = evento.matches;
};

onMounted(() => {
  if (!window.matchMedia) return;

  consulta = window.matchMedia(CONSULTA);
  ancorado.value = consulta.matches;
  consulta.addEventListener('change', sincronizar);
});

onBeforeUnmount(() => consulta?.removeEventListener('change', sincronizar));

const focus = () => nextTick(() => inspector.value?.focus());
const querySelector = selector => inspector.value?.querySelector(selector);

defineExpose({ focus, querySelector });
</script>

<template>
  <div>
    <div
      v-if="!ancorado"
      data-testid="kanban-workflow-inspector-backdrop"
      class="fixed inset-0 z-40 bg-n-slate-12/20"
      @click="emit('close')"
    />
    <aside
      ref="inspector"
      :data-testid="
        nodeSelected
          ? 'kanban-workflow-node-drawer'
          : 'kanban-workflow-connection-dialog'
      "
      class="fixed inset-x-4 bottom-4 top-4 z-50 grid max-h-[calc(100vh-2rem)] w-auto content-start gap-4 overflow-y-auto rounded-xl border border-n-weak bg-n-surface-1 p-4 shadow-lg outline-none sm:inset-x-auto sm:left-auto sm:right-4 sm:w-80 sm:p-5"
      role="dialog"
      :aria-modal="String(!ancorado)"
      :aria-labelledby="ariaLabelledby"
      tabindex="-1"
      @focusin="emit('focusin')"
      @keydown="emit('keydown', $event)"
    >
      <slot />
    </aside>
  </div>
</template>
