<script setup>
import { nextTick, ref } from 'vue';

defineProps({
  nodeSelected: { type: Boolean, default: false },
  ariaLabelledby: { type: String, required: true },
});

const emit = defineEmits(['close', 'focusin', 'keydown']);
const inspector = ref(null);

const focus = () => nextTick(() => inspector.value?.focus());
const querySelector = selector => inspector.value?.querySelector(selector);

defineExpose({ focus, querySelector });
</script>

<template>
  <div>
    <div
      data-testid="kanban-workflow-inspector-backdrop"
      class="fixed inset-0 z-40 bg-n-slate-12/10"
      @click="emit('close')"
    />
    <aside
      ref="inspector"
      :data-testid="
        nodeSelected
          ? 'kanban-workflow-node-drawer'
          : 'kanban-workflow-connection-dialog'
      "
      class="fixed inset-x-4 bottom-4 top-4 z-50 grid max-h-[calc(100vh-2rem)] w-auto content-start gap-4 overflow-y-auto rounded-xl border border-n-weak bg-n-surface-1 p-4 shadow-2xl outline-none sm:inset-x-auto sm:bottom-auto sm:right-4 sm:top-[4.5rem] sm:max-h-[min(34rem,calc(100vh-5rem))] sm:w-[min(16rem,calc(100vw-2rem))]"
      role="dialog"
      aria-modal="true"
      :aria-labelledby="ariaLabelledby"
      tabindex="-1"
      @focusin="emit('focusin')"
      @keydown="emit('keydown', $event)"
    >
      <slot />
    </aside>
  </div>
</template>
