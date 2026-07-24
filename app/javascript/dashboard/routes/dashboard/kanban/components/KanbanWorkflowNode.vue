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
    class="min-w-40 rounded-md border bg-n-surface-1 px-3 py-2 shadow-sm"
    :class="
      data.invalid ? 'border-n-ruby-9 ring-2 ring-n-ruby-9/20' : 'border-n-weak'
    "
  >
    <div class="flex items-center justify-between gap-2">
      <p class="m-0 text-xs font-medium text-n-slate-12">
        {{ data.label }}
      </p>
      <i
        v-if="data.invalid"
        class="i-lucide-circle-alert size-3.5 shrink-0 text-n-ruby-11"
        aria-hidden="true"
      />
    </div>
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
  <template v-else-if="data.kind === 'round_robin'">
    <div
      v-for="option in data.options"
      :key="option.id"
      class="nodrag nopan relative -mt-px flex min-w-40 items-center gap-2 border border-n-weak bg-n-surface-1 px-3 py-1.5 text-xs text-n-slate-11 first:mt-1"
    >
      <span class="min-w-0 flex-1 truncate">{{ option.label }}</span>
      <button
        type="button"
        class="flex size-5 items-center justify-center rounded text-n-brand hover:bg-n-surface-2 focus:outline-none focus:ring-2 focus:ring-n-brand"
        :aria-label="data.addAfterLabel"
        @click.stop="data.addAfterOption(data.id, option.id)"
      >
        <i class="i-lucide-plus size-3" />
      </button>
      <Handle
        :id="option.id"
        type="source"
        :position="Position.Right"
        class="!static !size-3 !border-2 !border-n-surface-1 !bg-n-brand"
      />
    </div>
  </template>
  <button
    v-else-if="data.canAddAfter"
    type="button"
    class="nodrag nopan absolute -right-3 top-full z-10 flex size-6 -translate-y-1/2 items-center justify-center rounded-full border border-n-brand bg-n-surface-1 text-n-brand shadow-sm hover:bg-n-brand hover:text-white focus:outline-none focus:ring-2 focus:ring-n-brand"
    :aria-label="data.addAfterLabel"
    @click.stop="data.addAfter(data.id)"
  >
    <i class="i-lucide-plus size-3" />
  </button>
  <Handle
    v-if="
      data.kind !== 'end' && !['condition', 'round_robin'].includes(data.kind)
    "
    type="source"
    :position="Position.Right"
    class="!size-3 !border-2 !border-n-surface-1 !bg-n-brand"
  />
</template>
