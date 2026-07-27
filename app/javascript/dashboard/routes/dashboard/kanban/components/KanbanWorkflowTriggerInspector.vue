<script setup>
const props = defineProps({
  triggerValue: { type: String, required: true },
  triggerOptions: { type: Array, default: () => [] },
  triggerContext: { type: String, default: null },
  config: { type: Object, default: () => ({}) },
  stages: { type: Array, default: () => [] },
  agents: { type: Array, default: () => [] },
  fields: { type: Array, default: () => [] },
  nextActionTypes: { type: Array, default: () => [] },
  connections: { type: Array, default: () => [] },
  lostReasons: { type: Array, default: () => [] },
  t: { type: Function, required: true },
});

const emit = defineEmits(['update:triggerValue', 'update:config']);

const updateConfig = (key, value) => emit('update:config', { [key]: value });

const stageEvents = ['kanban.card.created', 'kanban.card.stage_changed'];

const toggleStageEvent = (eventName, checked) => {
  const selected = new Set(props.config.triggerEventNames || []);
  if (checked) selected.add(eventName);
  else selected.delete(eventName);

  updateConfig('triggerEventNames', [...selected]);
};
</script>

<template>
  <section data-testid="kanban-workflow-trigger-inspector" class="grid gap-3">
    <label class="grid gap-1 text-xs font-medium text-n-slate-11">
      {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.EVENT') }}
      <select
        :value="triggerValue"
        data-testid="kanban-workflow-trigger-select"
        class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
        @change="emit('update:triggerValue', $event.target.value)"
      >
        <option
          v-for="option in triggerOptions"
          :key="option.value"
          :value="option.value"
        >
          {{ option.label }}
        </option>
      </select>
    </label>

    <template v-if="triggerContext === 'stage'">
      <fieldset class="grid gap-1.5">
        <legend class="text-xs font-medium text-n-slate-11">
          {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.STAGE_TRIGGER_EVENTS') }}
        </legend>
        <label
          v-for="eventName in stageEvents"
          :key="eventName"
          class="flex items-center gap-1.5 text-xs text-n-slate-12"
        >
          <input
            :checked="config.triggerEventNames?.includes(eventName)"
            type="checkbox"
            class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
            @change="toggleStageEvent(eventName, $event.target.checked)"
          />
          {{
            eventName === 'kanban.card.created'
              ? t('KANBAN.SETTINGS.AUTOMATIONS.RULES.CREATED_IN_STAGE')
              : t('KANBAN.SETTINGS.AUTOMATIONS.RULES.MOVED_TO_STAGE')
          }}
        </label>
      </fieldset>
      <label class="grid gap-1 text-xs font-medium text-n-slate-11">
        {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.STAGE_TRIGGER_EVENTS') }}
        <select
          :value="config.stageId || ''"
          data-testid="kanban-workflow-trigger-stage"
          class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          @change="updateConfig('stageId', $event.target.value)"
        >
          <option value="">
            {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.ANY_STAGE') }}
          </option>
          <option v-for="stage in stages" :key="stage.id" :value="stage.id">
            {{ stage.name }}
          </option>
        </select>
      </label>
    </template>

    <template v-else-if="triggerContext === 'customer_message'">
      <label class="grid gap-1 text-xs font-medium text-n-slate-11">
        {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.CUSTOMER_MESSAGE_PHRASE') }}
        <select
          :value="config.customerMessageMode || 'any'"
          class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          @change="updateConfig('customerMessageMode', $event.target.value)"
        >
          <option value="any">
            {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.CUSTOMER_MESSAGE_ANY') }}
          </option>
          <option value="contains">
            {{
              t('KANBAN.SETTINGS.AUTOMATIONS.RULES.CUSTOMER_MESSAGE_CONTAINS')
            }}
          </option>
        </select>
      </label>
      <label
        v-if="config.customerMessageMode === 'contains'"
        class="grid gap-1 text-xs font-medium text-n-slate-11"
      >
        {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.CUSTOMER_MESSAGE_PHRASE') }}
        <input
          :value="config.customerMessageContains || ''"
          type="text"
          class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          @input="updateConfig('customerMessageContains', $event.target.value)"
        />
      </label>
    </template>

    <label
      v-else-if="triggerContext === 'owner'"
      class="grid gap-1 text-xs font-medium text-n-slate-11"
    >
      {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SELECT_OWNER') }}
      <select
        :value="config.ownerId || ''"
        class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
        @change="updateConfig('ownerId', $event.target.value)"
      >
        <option value="">
          {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.ANY_OWNER') }}
        </option>
        <option v-for="agent in agents" :key="agent.value" :value="agent.value">
          {{ agent.label }}
        </option>
      </select>
    </label>

    <label
      v-else-if="triggerContext === 'changed_field'"
      class="grid gap-1 text-xs font-medium text-n-slate-11"
    >
      {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SELECT_FIELD') }}
      <select
        :value="config.changedFieldKey || ''"
        class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
        @change="updateConfig('changedFieldKey', $event.target.value)"
      >
        <option value="">
          {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.ANY_FIELD') }}
        </option>
        <option v-for="field in fields" :key="field.key" :value="field.key">
          {{ field.label }}
        </option>
      </select>
    </label>

    <label
      v-else-if="triggerContext === 'next_action'"
      class="grid gap-1 text-xs font-medium text-n-slate-11"
    >
      {{ t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.NEXT_ACTION_TYPE') }}
      <select
        :value="config.triggerNextActionType || ''"
        class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
        @change="updateConfig('triggerNextActionType', $event.target.value)"
      >
        <option value="">
          {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.ANY_FIELD') }}
        </option>
        <option
          v-for="actionType in nextActionTypes"
          :key="actionType"
          :value="actionType"
        >
          {{ actionType }}
        </option>
      </select>
    </label>

    <template v-else-if="triggerContext === 'amount'">
      <label class="grid gap-1 text-xs font-medium text-n-slate-11">
        {{ t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.AMOUNT') }}
        <select
          :value="config.triggerAmountMode || 'any'"
          class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          @change="updateConfig('triggerAmountMode', $event.target.value)"
        >
          <option value="any">
            {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.ANY_AMOUNT_CHANGE') }}
          </option>
          <option value="new_value">
            {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.AMOUNT_NEW_VALUE') }}
          </option>
        </select>
      </label>
      <div
        v-if="config.triggerAmountMode === 'new_value'"
        class="grid grid-cols-[minmax(0,1fr)_minmax(0,1fr)] gap-2"
      >
        <select
          :value="config.triggerAmountOperator || 'greater_than'"
          class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          @change="updateConfig('triggerAmountOperator', $event.target.value)"
        >
          <option value="equals">
            {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.EQUALS') }}
          </option>
          <option value="greater_than">
            {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.GREATER_THAN') }}
          </option>
          <option value="less_than">
            {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.LESS_THAN') }}
          </option>
        </select>
        <input
          :value="config.triggerAmountValue || ''"
          type="number"
          min="0"
          inputmode="decimal"
          :placeholder="t('KANBAN.SETTINGS.AUTOMATIONS.RULES.VALUE')"
          class="h-9 min-w-0 rounded-md border border-n-weak bg-n-surface-2 px-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          @input="updateConfig('triggerAmountValue', $event.target.value)"
        />
      </div>
    </template>

    <label
      v-else-if="triggerContext === 'webhook'"
      class="grid gap-1 text-xs font-medium text-n-slate-11"
    >
      {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.SELECT_CONNECTION') }}
      <select
        :value="config.connectionId || ''"
        class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
        @change="updateConfig('connectionId', $event.target.value)"
      >
        <option value="">
          {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.ANY_CONNECTION') }}
        </option>
        <option
          v-for="connection in connections"
          :key="connection.id"
          :value="connection.id"
        >
          {{ connection.name }}
        </option>
      </select>
    </label>

    <label
      v-else-if="triggerContext === 'lost_reason'"
      class="grid gap-1 text-xs font-medium text-n-slate-11"
    >
      {{ t('KANBAN.SETTINGS.SALES.SYSTEM_FIELDS.LOST_REASON') }}
      <select
        :value="config.triggerLostReason || ''"
        class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
        @change="updateConfig('triggerLostReason', $event.target.value)"
      >
        <option value="">
          {{ t('KANBAN.SETTINGS.AUTOMATIONS.RULES.ANY_FIELD') }}
        </option>
        <option v-for="reason in lostReasons" :key="reason" :value="reason">
          {{ reason }}
        </option>
      </select>
    </label>
  </section>
</template>
