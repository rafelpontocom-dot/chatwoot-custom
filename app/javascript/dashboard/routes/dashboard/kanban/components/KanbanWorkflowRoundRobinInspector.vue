<script setup>
import { computed } from 'vue';

const props = defineProps({
  node: { type: Object, required: true },
  t: { type: Function, required: true },
});

const emit = defineEmits(['add', 'remove', 'update']);
const data = computed(() => props.node.data);
</script>

<template>
  <!-- eslint-disable vue/html-closing-bracket-newline -->
  <section
    class="grid gap-3 rounded-lg border border-n-weak bg-n-surface-2 p-3"
  >
    <div>
      <p class="m-0 text-sm font-semibold text-n-slate-12">
        {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.ROUND_ROBIN') }}
      </p>
      <p class="m-0 mt-1 text-xs text-n-slate-11">
        {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.ROUND_ROBIN_HINT') }}
      </p>
    </div>
    <div class="grid gap-2">
      <div
        v-for="(option, index) in data.options"
        :key="option.id"
        class="grid grid-cols-[minmax(0,1fr)_2rem] gap-2 rounded-md border border-n-weak bg-n-surface-1 p-2"
      >
        <input
          v-model="option.label"
          type="text"
          class="h-9 min-w-0 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          @change="emit('update')"
        />
        <button
          type="button"
          class="flex p-0 size-9 items-center justify-center rounded-md text-n-ruby-11 hover:bg-n-ruby-3 focus:outline-none focus:ring-2 focus:ring-n-brand disabled:cursor-not-allowed disabled:opacity-40"
          :aria-label="
            t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.ROUND_ROBIN_REMOVE_OPTION')
          "
          :title="
            t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.ROUND_ROBIN_REMOVE_OPTION')
          "
          :disabled="data.options.length <= 2"
          @click="emit('remove', index)"
        >
          <i class="i-lucide-trash-2 size-4" aria-hidden="true" />
        </button>
      </div>
    </div>
    <p class="m-0 text-xs text-n-slate-11">
      {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.ROUND_ROBIN_RESET_HINT') }}
    </p>
    <button
      type="button"
      data-testid="kanban-workflow-add-round-robin-option"
      class="flex h-8 w-fit items-center gap-1 rounded-md border border-solid border-n-weak bg-n-surface-1 px-2 text-xs font-medium text-n-slate-12 hover:bg-n-surface-2 focus:outline-none focus:ring-2 focus:ring-n-brand"
      @click="emit('add')"
    >
      <i class="i-lucide-plus size-3.5" aria-hidden="true" />{{
        t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.ROUND_ROBIN_ADD_OPTION')
      }}
    </button>
  </section>
</template>
