<script setup>
import { computed } from 'vue';

const props = defineProps({
  node: { type: Object, required: true },
  stages: { type: Array, default: () => [] },
  t: { type: Function, required: true },
});

const emit = defineEmits(['update']);
const data = computed(() => props.node.data);
</script>

<template>
  <section class="grid gap-3">
    <div class="rounded-lg border border-n-weak bg-n-surface-2 p-3">
      <p class="m-0 text-sm font-semibold text-n-slate-12">
        {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.CREATE_OPPORTUNITY') }}
      </p>
      <p class="m-0 mt-1 text-xs text-n-slate-11">
        {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CREATE_OPPORTUNITY_HINT') }}
      </p>
    </div>

    <label class="grid gap-1 text-xs font-medium text-n-slate-11">
      {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CREATE_OPPORTUNITY_STAGE') }}
      <select
        v-model="data.stage_id"
        data-testid="kanban-workflow-create-opportunity-stage"
        class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
        @change="emit('update')"
      >
        <option value="">
          {{
            t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CREATE_OPPORTUNITY_STAGE')
          }}
        </option>
        <option v-for="stage in stages" :key="stage.id" :value="stage.id">
          {{ stage.name }}
        </option>
      </select>
    </label>

    <label class="grid gap-1 text-xs font-medium text-n-slate-11">
      {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CREATE_OPPORTUNITY_SUBJECT') }}
      <input
        v-model="data.subject"
        data-testid="kanban-workflow-create-opportunity-subject"
        type="text"
        class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
        @change="emit('update')"
      />
    </label>
  </section>
</template>
