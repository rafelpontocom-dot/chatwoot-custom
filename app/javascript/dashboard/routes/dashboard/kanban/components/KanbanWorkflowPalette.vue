<script setup>
import { computed, ref } from 'vue';

const props = defineProps({
  groups: {
    type: Array,
    default: () => [],
  },
  title: {
    type: String,
    required: true,
  },
  searchPlaceholder: {
    type: String,
    required: true,
  },
  emptyLabel: {
    type: String,
    required: true,
  },
  mobile: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['add', 'drag-start']);
const query = ref('');
const openGroups = ref(new Set(['DECISION']));

const categoryTone = category =>
  ({
    DECISION: 'text-n-violet-11',
    TIME: 'text-n-amber-11',
    CUSTOMER: 'text-n-blue-11',
    OPPORTUNITY: 'text-n-iris-11',
    OPERATION: 'text-n-cyan-11',
    INTEGRATION: 'text-n-slate-11',
  })[category] || 'text-n-slate-10';

const visibleGroups = computed(() => {
  const normalizedQuery = query.value.trim().toLocaleLowerCase();
  return props.groups
    .map(group => ({
      ...group,
      nodes: group.nodes.filter(
        node =>
          !normalizedQuery ||
          node.label.toLocaleLowerCase().includes(normalizedQuery)
      ),
    }))
    .filter(group => group.nodes.length);
});

const setGroupOpen = (key, event) => {
  const nextOpenGroups = new Set(openGroups.value);

  if (event.target.open) nextOpenGroups.add(key);
  else nextOpenGroups.delete(key);

  openGroups.value = nextOpenGroups;
};
</script>

<template>
  <aside
    data-testid="kanban-workflow-palette"
    :class="
      mobile
        ? 'flex min-h-0 flex-1 w-full flex-col bg-n-surface-1'
        : 'hidden w-52 shrink-0 flex-col border-r border-n-weak bg-n-surface-1 lg:flex'
    "
  >
    <div
      data-testid="kanban-workflow-palette-header"
      class="border-b border-n-weak px-3 py-2.5"
    >
      <p
        class="m-0 text-xs font-semibold uppercase tracking-wide text-n-slate-10"
      >
        {{ title }}
      </p>
      <label class="relative mt-2 block">
        <i
          class="i-lucide-search pointer-events-none absolute left-2.5 top-1/2 size-4 -translate-y-1/2 text-n-slate-10"
        />
        <input
          v-model="query"
          data-testid="kanban-workflow-palette-search"
          type="search"
          class="h-8 w-full rounded-md border border-n-weak bg-n-surface-2 py-1 pl-8 pr-2 text-xs text-n-slate-12 outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
          :placeholder="searchPlaceholder"
        />
      </label>
    </div>
    <div class="min-h-0 flex-1 overflow-y-auto px-2 py-1.5">
      <details
        v-for="group in visibleGroups"
        :key="group.key"
        data-testid="kanban-workflow-palette-group"
        :open="Boolean(query) || openGroups.has(group.key)"
        class="group border-b border-n-weak last:border-0"
        @toggle="setGroupOpen(group.key, $event)"
      >
        <summary
          class="flex h-8 cursor-pointer list-none items-center gap-2 px-1 text-xs font-semibold text-n-slate-11 marker:content-none"
        >
          <i
            data-testid="kanban-workflow-palette-group-icon"
            class="size-3.5"
            :class="[group.icon, categoryTone(group.key)]"
            aria-hidden="true"
          />
          <span class="flex-1">{{ group.label }}</span>
          <i
            class="i-lucide-chevron-down size-3.5 transition-transform group-open:rotate-180"
          />
        </summary>
        <div class="grid gap-0.5 pb-2">
          <button
            v-for="node in group.nodes"
            :key="node.type"
            type="button"
            draggable="true"
            data-testid="kanban-workflow-palette-node"
            class="flex h-8 items-center rounded-md px-2 text-left text-xs font-medium text-n-slate-12 hover:bg-n-surface-2 focus:outline-none focus:ring-2 focus:ring-n-brand"
            @dragstart="
              event => {
                event.dataTransfer.effectAllowed = 'move';
                event.dataTransfer.setData(
                  'application/x-kanban-workflow-node',
                  node.type
                );
                emit('drag-start', node.type);
              }
            "
            @click="emit('add', node.type)"
          >
            <i
              v-if="node.icon"
              data-testid="kanban-workflow-palette-node-icon"
              class="mr-2 size-4 shrink-0 text-n-slate-10"
              :class="node.icon"
              aria-hidden="true"
            />
            {{ node.label }}
          </button>
        </div>
      </details>
      <p v-if="!visibleGroups.length" class="m-0 p-2 text-xs text-n-slate-10">
        {{ emptyLabel }}
      </p>
    </div>
  </aside>
</template>
