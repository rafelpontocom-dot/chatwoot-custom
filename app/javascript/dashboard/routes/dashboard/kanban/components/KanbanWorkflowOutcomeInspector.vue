<script setup>
import { computed } from 'vue';

const props = defineProps({
  node: { type: Object, required: true },
  nextActionTypes: { type: Array, default: () => [] },
  lostReasons: { type: Array, default: () => [] },
  t: { type: Function, required: true },
});

const emit = defineEmits(['update']);
const params = computed(() => props.node.data.action_params);
</script>

<template>
  <section class="grid gap-3">
    <div class="rounded-lg border border-n-weak bg-n-surface-2 p-3">
      <p class="m-0 text-sm font-semibold text-n-slate-12">
        <template v-if="node.type === 'complete_next_action'">
          {{
            t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.COMPLETE_NEXT_ACTION')
          }}
        </template>
        <template v-else-if="node.type === 'mark_won'">
          {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.MARK_WON') }}
        </template>
        <template v-else>
          {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.MARK_LOST') }}
        </template>
      </p>
      <p class="m-0 mt-1 text-xs text-n-slate-11">
        <template v-if="node.type === 'complete_next_action'">
          {{
            t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.COMPLETE_NEXT_ACTION_HINT')
          }}
        </template>
        <template v-else-if="node.type === 'mark_won'">
          {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.MARK_WON_HINT') }}
        </template>
        <template v-else>
          {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODE_HINT') }}
        </template>
      </p>
    </div>

    <template v-if="node.type === 'complete_next_action'">
      <label class="grid gap-1 text-xs font-medium text-n-slate-11">
        {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.COMPLETION_NOTE') }}
        <textarea
          v-model="params.completion_note"
          data-testid="kanban-workflow-completion-note"
          rows="3"
          class="resize-y rounded-md border border-n-weak bg-n-surface-2 px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          @change="emit('update')"
        />
      </label>
      <label
        class="flex items-center gap-2 rounded-md border border-n-weak bg-n-surface-2 px-3 py-2 text-xs font-medium text-n-slate-11"
      >
        <input
          v-model="params.schedule_next_action"
          data-testid="kanban-workflow-schedule-next-action"
          type="checkbox"
          class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
          @change="emit('update')"
        />
        {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.SCHEDULE_NEXT_ACTION') }}
      </label>
      <div
        v-if="params.schedule_next_action"
        class="grid gap-3 rounded-md border border-n-weak bg-n-surface-2 p-3"
      >
        <label class="grid gap-1 text-xs font-medium text-n-slate-11">
          {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SELECT_NEXT_ACTION') }}
          <select
            v-model="params.next_action_type"
            data-testid="kanban-workflow-next-action-type"
            class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
            @change="emit('update')"
          >
            <option value="">
              {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SELECT_NEXT_ACTION') }}
            </option>
            <option v-for="type in nextActionTypes" :key="type" :value="type">
              {{ type }}
            </option>
          </select>
        </label>
        <label class="grid gap-1 text-xs font-medium text-n-slate-11">
          {{ t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.NEXT_ACTION_AT') }}
          <input
            v-model="params.next_action_at"
            type="datetime-local"
            class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
            @change="emit('update')"
          />
        </label>
        <label class="grid gap-1 text-xs font-medium text-n-slate-11">
          {{ t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.NEXT_ACTION_NOTE') }}
          <input
            v-model="params.next_action_note"
            type="text"
            class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
            @change="emit('update')"
          />
        </label>
      </div>
    </template>

    <label
      v-else-if="node.type === 'mark_lost'"
      class="grid gap-1 text-xs font-medium text-n-slate-11"
    >
      {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.LOST_REASON') }}
      <select
        v-model="params.lost_reason"
        data-testid="kanban-workflow-lost-reason"
        class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
        @change="emit('update')"
      >
        <option value="">
          {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.LOST_REASON') }}
        </option>
        <option v-for="reason in lostReasons" :key="reason" :value="reason">
          {{ reason }}
        </option>
      </select>
    </label>
  </section>
</template>
