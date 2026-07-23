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
  <Handle
    v-if="data.kind !== 'end'"
    type="source"
    :position="Position.Right"
    class="!size-3 !border-2 !border-n-surface-1 !bg-n-brand"
  />
</template>
