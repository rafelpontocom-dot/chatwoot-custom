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
        : 'hidden w-[12.25rem] shrink-0 flex-col border-r border-n-weak bg-n-surface-1 lg:flex'
    "
  >
    <div
      data-testid="kanban-workflow-palette-header"
      class="border-b border-n-weak bg-n-surface-1 px-3 py-3"
    >
      <div class="flex items-center justify-between gap-2">
        <p
          class="m-0 text-xs font-semibold uppercase tracking-wide text-n-slate-10"
        >
          {{ title }}
        </p>
        <span
          data-testid="kanban-workflow-palette-count"
          class="inline-flex min-w-5 items-center justify-center rounded-full bg-n-surface-1 px-1.5 py-0.5 text-2xs font-semibold text-n-slate-11 ring-1 ring-n-weak"
        >
          {{ groups.reduce((total, group) => total + group.nodes.length, 0) }}
        </span>
      </div>
      <label class="relative mt-2 block">
        <i
          class="i-lucide-search pointer-events-none absolute left-2.5 top-1/2 size-4 -translate-y-1/2 text-n-slate-10"
        />
        <input
          v-model="query"
          data-testid="kanban-workflow-palette-search"
          type="search"
          class="h-8 w-full rounded-md border border-n-weak bg-n-surface-2 py-1 pl-8 pr-2 text-xs text-n-slate-12 outline-none transition focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
          :placeholder="searchPlaceholder"
        />
      </label>
    </div>
    <div class="min-h-0 flex-1 overflow-y-auto px-2 py-2">
      <details
        v-for="group in visibleGroups"
        :key="group.key"
        data-testid="kanban-workflow-palette-group"
        :open="Boolean(query) || openGroups.has(group.key)"
        class="group mb-1 last:mb-0"
        @toggle="setGroupOpen(group.key, $event)"
      >
        <summary
          class="flex h-6 cursor-pointer list-none items-center gap-2 px-1.5 text-micro font-medium uppercase tracking-wide text-n-slate-10 marker:content-none hover:text-n-slate-12"
        >
          <i
            data-testid="kanban-workflow-palette-group-icon"
            class="size-3.5"
            :class="[group.icon, categoryTone(group.key)]"
            aria-hidden="true"
          />
          <span class="flex-1">{{ group.label }}</span>
          <span class="text-2xs font-medium text-n-slate-10">
            {{ group.nodes.length }}
          </span>
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
            class="group/item flex min-h-9 items-center rounded-md border border-transparent px-2 text-left text-xs font-medium text-n-slate-12 transition hover:border-n-weak hover:bg-n-surface-2 focus:outline-none focus:ring-2 focus:ring-n-brand"
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
              class="mr-2 size-3.5 shrink-0"
              :class="[categoryTone(group.key), node.icon]"
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
