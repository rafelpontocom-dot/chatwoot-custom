<script setup>
import { Handle, Position } from '@vue-flow/core';

defineProps({
  data: {
    type: Object,
    required: true,
  },
});
</script>

<template>
  <Handle
    v-if="data.kind !== 'trigger'"
    type="target"
    :position="Position.Left"
    class="!size-3 !border-2 !border-n-surface-1 !bg-n-slate-9"
  />
  <div
    class="min-w-40 rounded-md border border-n-weak bg-n-surface-1 px-3 py-2 shadow-sm"
  >
    <p class="m-0 text-xs font-medium text-n-slate-12">
      {{ data.label }}
    </p>
    <p v-if="data.summary" class="m-0 mt-1 text-xs text-n-slate-10">
      {{ data.summary }}
    </p>
  </div>
  <template v-if="data.kind === 'condition'">
    <span
      class="pointer-events-none absolute -right-8 top-3 text-[10px] text-n-slate-10"
    >
      {{ data.yesLabel }}
    </span>
    <Handle
      id="yes"
      type="source"
      :position="Position.Right"
      class="!top-4 !size-3 !border-2 !border-n-surface-1 !bg-n-brand"
    />
    <span
      class="pointer-events-none absolute -right-8 bottom-3 text-[10px] text-n-slate-10"
    >
      {{ data.noLabel }}
    </span>
    <Handle
      id="no"
      type="source"
      :position="Position.Right"
      class="!bottom-4 !top-auto !size-3 !border-2 !border-n-surface-1 !bg-n-ruby-9"
    />
  </template>
  <button
    v-else-if="data.canAddAfter"
    type="button"
    class="nodrag nopan absolute -right-5 top-1/2 flex size-5 -translate-y-1/2 items-center justify-center rounded-full border border-n-weak bg-n-surface-1 text-n-slate-11 shadow-sm hover:bg-n-surface-2 focus:outline-none focus:ring-2 focus:ring-n-brand"
    :aria-label="data.addAfterLabel"
    @click.stop="data.addAfter(data.id)"
  >
    <i class="i-lucide-plus size-3" />
  </button>
  <Handle
    v-else-if="data.kind !== 'end'"
    type="source"
    :position="Position.Right"
    class="!size-3 !border-2 !border-n-surface-1 !bg-n-brand"
  />
</template>
