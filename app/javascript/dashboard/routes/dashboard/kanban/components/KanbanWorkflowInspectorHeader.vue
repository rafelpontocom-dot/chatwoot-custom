<script setup>
defineProps({
  node: { type: Object, required: true },
  summary: { type: String, required: true },
  stateTone: { type: String, required: true },
  surfaceClass: { type: String, required: true },
  emptySummary: { type: String, required: true },
  connectLabel: { type: String, required: true },
  closeLabel: { type: String, required: true },
  deleteLabel: { type: String, required: true },
});

const emit = defineEmits(['close', 'connect', 'delete']);
</script>

<template>
  <div
    data-testid="kanban-workflow-inspector-header"
    class="sticky top-0 z-10 -mx-4 -mt-4 flex items-center justify-between gap-3 border-b border-n-weak bg-n-surface-1 px-4 pb-3 pt-4 sm:-mx-5 sm:-mt-5 sm:px-5 sm:pt-5"
  >
    <div class="flex min-w-0 items-center gap-2.5">
      <span
        data-testid="kanban-workflow-inspector-icon-surface"
        class="flex size-10 shrink-0 items-center justify-center rounded-lg"
        :class="surfaceClass"
      >
        <i
          v-if="node.data.icon"
          data-testid="kanban-workflow-inspector-icon"
          class="size-4"
          :class="node.data.icon"
          aria-hidden="true"
        />
      </span>
      <div class="min-w-0">
        <p
          data-testid="kanban-workflow-inspector-category"
          class="m-0 truncate text-2xs font-semibold uppercase tracking-wide text-n-slate-10"
        >
          {{ node.data.categoryLabel }}
        </p>
        <p
          id="kanban-workflow-inspector-title"
          class="m-0 truncate text-base font-semibold text-n-slate-12"
        >
          {{ node.data.label }}
        </p>
        <span
          data-testid="kanban-workflow-inspector-state"
          class="mt-1 inline-flex rounded-full px-1.5 py-0.5 text-2xs font-medium"
          :class="stateTone"
        >
          {{ node.data.stateLabel }}
        </span>
      </div>
    </div>
    <div class="flex items-center gap-1">
      <button
        v-if="!node.data.terminal"
        type="button"
        data-testid="kanban-workflow-connect-node"
        class="flex size-8 items-center justify-center rounded-md text-n-slate-10 hover:bg-n-surface-2 hover:text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
        :aria-label="connectLabel"
        :title="connectLabel"
        @click="emit('connect')"
      >
        <i class="i-lucide-link size-4" aria-hidden="true" />
      </button>
      <button
        type="button"
        class="flex size-8 items-center justify-center rounded-md text-n-slate-10 hover:bg-n-surface-2 hover:text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
        :aria-label="closeLabel"
        :title="closeLabel"
        @click="emit('close')"
      >
        <i class="i-lucide-x size-4" aria-hidden="true" />
      </button>
      <button
        v-if="!['trigger', 'end'].includes(node.type)"
        type="button"
        class="flex size-8 items-center justify-center rounded-md text-n-ruby-11 hover:bg-n-ruby-3 focus:outline-none focus:ring-2 focus:ring-n-brand"
        :aria-label="deleteLabel"
        :title="deleteLabel"
        @click="emit('delete')"
      >
        <i class="i-lucide-trash-2 size-4" aria-hidden="true" />
      </button>
    </div>
  </div>

  <div
    data-testid="kanban-workflow-inspector-summary"
    class="rounded-lg border border-n-weak bg-n-surface-2 px-3 py-2"
  >
    <p
      class="m-0 text-2xs font-semibold uppercase tracking-wide text-n-slate-10"
    >
      {{ node.data.categoryLabel }}
    </p>
    <p class="m-0 mt-1 text-xs text-n-slate-11">
      {{ summary || emptySummary }}
    </p>
  </div>
</template>
