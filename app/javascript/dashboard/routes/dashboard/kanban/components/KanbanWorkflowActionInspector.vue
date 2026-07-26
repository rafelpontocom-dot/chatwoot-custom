<script setup>
import { computed } from 'vue';

const props = defineProps({
  node: { type: Object, required: true },
  actionName: { type: String, required: true },
  actions: { type: Array, default: () => [] },
  stages: { type: Array, default: () => [] },
  agents: { type: Array, default: () => [] },
  nextActionTypes: { type: Array, default: () => [] },
  customFields: { type: Array, default: () => [] },
  numericFields: { type: Array, default: () => [] },
  fieldOptions: { type: Array, default: () => [] },
  availabilityPolicies: { type: Array, default: () => [] },
  t: { type: Function, required: true },
});

const emit = defineEmits(['update']);
const data = computed(() => props.node.data);
const params = computed(() => data.value.action_params);
const usesField = computed(() =>
  ['set_field', 'increment_field', 'clear_field'].includes(props.actionName)
);
const fieldChoices = computed(() =>
  props.actionName === 'increment_field'
    ? props.numericFields
    : props.customFields
);
const actionLabel = computed(() => {
  if (props.node.type === 'set_field') {
    return props.t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.SET_FIELD');
  }

  return (
    props.actions.find(action => action.value === props.actionName)?.label ||
    props.t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.ACTION')
  );
});
</script>

<template>
  <!-- eslint-disable vue/html-closing-bracket-newline, vue/multiline-html-element-content-newline -->
  <section class="grid gap-3">
    <div class="rounded-lg border border-n-weak bg-n-surface-2 p-3">
      <p class="m-0 text-sm font-semibold text-n-slate-12">
        {{ actionLabel }}
      </p>
      <p class="m-0 mt-1 text-xs text-n-slate-11">
        {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODE_HINT') }}
      </p>
    </div>

    <label
      v-if="node.type === 'action'"
      class="grid gap-1 text-xs font-medium text-n-slate-11"
    >
      {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.ACTION') }}
      <select
        v-model="data.action_name"
        class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
        @change="emit('update')"
      >
        <option
          v-for="option in actions"
          :key="option.value"
          :value="option.value"
        >
          {{ option.label }}
        </option>
      </select>
    </label>

    <label
      v-if="actionName === 'move_stage'"
      class="grid gap-1 text-xs font-medium text-n-slate-11"
    >
      {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.STAGE') }}
      <select
        v-model="params.stage_id"
        class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
        @change="emit('update')"
      >
        <option v-for="stage in stages" :key="stage.id" :value="stage.id">
          {{ stage.name }}
        </option>
      </select>
    </label>

    <label
      v-else-if="actionName === 'assign_owner'"
      class="grid gap-1 text-xs font-medium text-n-slate-11"
    >
      {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SELECT_OWNER') }}
      <select
        v-model="params.owner_id"
        class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
        @change="emit('update')"
      >
        <option value="">
          {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SELECT_OWNER') }}
        </option>
        <option v-for="agent in agents" :key="agent.value" :value="agent.value">
          {{ agent.label }}
        </option>
      </select>
    </label>

    <div
      v-else-if="actionName === 'assign_round_robin'"
      class="grid gap-3 rounded-md border border-n-weak bg-n-surface-2 p-3"
    >
      <label class="grid gap-1 text-xs font-medium text-n-slate-11"
        >{{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SELECT_OWNERS')
        }}<select
          v-model="params.owner_ids"
          multiple
          class="min-h-24 rounded-md border border-n-weak bg-n-surface-1 px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          @change="emit('update')"
        >
          <option
            v-for="agent in agents"
            :key="agent.value"
            :value="agent.value"
          >
            {{ agent.label }}
          </option>
        </select></label
      >
      <label class="grid gap-1 text-xs font-medium text-n-slate-11"
        >{{
          t(
            'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.ROUND_ROBIN_AVAILABILITY.ANY'
          )
        }}<select
          v-model="params.availability_policy"
          data-testid="kanban-workflow-round-robin-availability"
          class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          @change="emit('update')"
        >
          <option
            v-for="policy in availabilityPolicies"
            :key="policy.value"
            :value="policy.value"
          >
            {{ policy.label }}
          </option>
        </select></label
      >
    </div>

    <div v-else-if="actionName === 'set_next_action'" class="grid gap-3">
      <label class="grid gap-1 text-xs font-medium text-n-slate-11"
        >{{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SELECT_NEXT_ACTION')
        }}<select
          v-model="params.next_action_type"
          class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          @change="emit('update')"
        >
          <option value="">
            {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SELECT_NEXT_ACTION') }}
          </option>
          <option v-for="type in nextActionTypes" :key="type" :value="type">
            {{ type }}
          </option>
        </select></label
      >
      <label class="grid gap-1 text-xs font-medium text-n-slate-11"
        >{{ t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.NEXT_ACTION_AT')
        }}<input
          v-model="params.next_action_at"
          type="datetime-local"
          class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          @change="emit('update')"
      /></label>
      <label class="grid gap-1 text-xs font-medium text-n-slate-11"
        >{{ t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.NEXT_ACTION_NOTE')
        }}<input
          v-model="params.next_action_note"
          type="text"
          class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          @change="emit('update')"
      /></label>
    </div>

    <div v-else-if="usesField" class="grid gap-3">
      <label class="grid gap-1 text-xs font-medium text-n-slate-11"
        >{{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SELECT_FIELD')
        }}<select
          v-model="params.field_key"
          class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          @change="emit('update')"
        >
          <option value="">
            {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SELECT_FIELD') }}
          </option>
          <option
            v-for="field in fieldChoices"
            :key="field.key"
            :value="field.key"
          >
            {{ field.label || field.key }}
          </option>
        </select></label
      >
      <label
        v-if="actionName !== 'clear_field'"
        class="grid gap-1 text-xs font-medium text-n-slate-11"
        >{{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.VALUE')
        }}<select
          v-if="fieldOptions.length && actionName === 'set_field'"
          v-model="params.value"
          data-testid="kanban-workflow-action-field-value"
          class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          @change="emit('update')"
        >
          <option value="">
            {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.VALUE') }}
          </option>
          <option v-for="option in fieldOptions" :key="option" :value="option">
            {{ option }}
          </option></select
        ><input
          v-else
          v-model="
            params[actionName === 'increment_field' ? 'amount' : 'value']
          "
          :type="actionName === 'increment_field' ? 'number' : 'text'"
          :step="actionName === 'increment_field' ? 'any' : undefined"
          data-testid="kanban-workflow-action-field-value"
          class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          @change="emit('update')"
      /></label>
    </div>

    <label
      v-else-if="['add_label', 'remove_label'].includes(actionName)"
      class="grid gap-1 text-xs font-medium text-n-slate-11"
      >{{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.LABEL')
      }}<input
        v-model="params.label"
        type="text"
        class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
        @change="emit('update')"
    /></label>
    <label
      v-else-if="actionName === 'add_note'"
      class="grid gap-1 text-xs font-medium text-n-slate-11"
      >{{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NOTE_CONTENT')
      }}<textarea
        v-model="params.content"
        rows="3"
        class="resize-y rounded-md border border-n-weak bg-n-surface-2 px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
        @change="emit('update')"
      />
    </label>
  </section>
</template>
