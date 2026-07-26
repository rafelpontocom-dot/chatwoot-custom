<script setup>
defineProps({
  tabs: { type: Array, required: true },
  activeTab: { type: String, required: true },
  label: { type: String, required: true },
  tabLabel: { type: Function, required: true },
  tabIcon: { type: Function, required: true },
});

const emit = defineEmits(['update:activeTab', 'keydown']);
</script>

<template>
  <div
    data-testid="kanban-workflow-inspector-tabs"
    class="grid w-full grid-cols-3 items-center gap-1 rounded-lg bg-n-surface-2 p-1"
    role="tablist"
    :aria-label="label"
  >
    <button
      v-for="tab in tabs"
      :key="tab"
      type="button"
      :data-testid="`kanban-workflow-inspector-tab-${tab}`"
      :data-inspector-tab="tab"
      role="tab"
      :aria-selected="activeTab === tab"
      :tabindex="activeTab === tab ? 0 : -1"
      class="flex h-8 items-center justify-center gap-1.5 rounded px-2 text-xs font-medium focus:outline-none focus:ring-2 focus:ring-n-brand"
      :class="
        activeTab === tab
          ? 'bg-n-surface-1 text-n-slate-12 shadow-sm'
          : 'text-n-slate-11 hover:text-n-slate-12'
      "
      @click="emit('update:activeTab', tab)"
      @keydown="emit('keydown', $event, tab)"
    >
      <i :class="tabIcon(tab)" class="size-3.5 shrink-0" aria-hidden="true" />
      {{ tabLabel(tab) }}
    </button>
  </div>
</template>
