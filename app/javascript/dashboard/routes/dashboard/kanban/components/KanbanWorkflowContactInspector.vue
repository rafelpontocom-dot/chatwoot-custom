<script setup>
import { computed } from 'vue';

const props = defineProps({
  node: { type: Object, required: true },
  attributes: { type: Array, default: () => [] },
  selectedAttribute: { type: String, required: true },
  isBoolean: { type: Boolean, default: false },
  booleanValue: { type: Boolean, default: false },
  isDate: { type: Boolean, default: false },
  t: { type: Function, required: true },
});

const emit = defineEmits(['update', 'select-attribute', 'update-boolean']);
const data = computed(() => props.node.data);
</script>

<template>
  <section class="grid gap-3">
    <div class="rounded-lg border border-n-weak bg-n-surface-2 p-3">
      <p class="m-0 text-sm font-semibold text-n-slate-12">
        {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.UPDATE_CONTACT') }}
      </p>
      <p class="m-0 mt-1 text-xs text-n-slate-11">
        {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CONTACT_UPDATE_HINT') }}
      </p>
    </div>

    <label class="grid gap-1 text-xs font-medium text-n-slate-11">
      {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CONTACT_ATTRIBUTE') }}
      <select
        :value="selectedAttribute"
        data-testid="kanban-workflow-contact-attribute-select"
        class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
        @change="emit('select-attribute', $event)"
      >
        <option
          v-for="attribute in attributes"
          :key="attribute.value"
          :value="attribute.value"
        >
          {{ attribute.label }}
        </option>
        <option value="__custom__">
          {{
            t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CONTACT_ATTRIBUTES.CUSTOM')
          }}
        </option>
      </select>
    </label>

    <label
      v-if="selectedAttribute === '__custom__'"
      class="grid gap-1 text-xs font-medium text-n-slate-11"
    >
      {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CONTACT_ATTRIBUTE_KEY') }}
      <input
        v-model="data.action_params.attribute_key"
        data-testid="kanban-workflow-contact-attribute"
        class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
        @change="emit('update')"
      />
    </label>

    <label
      v-if="isBoolean"
      class="flex min-h-9 items-center gap-2 rounded-md border border-n-weak bg-n-surface-2 px-3 text-xs font-medium text-n-slate-11"
    >
      <input
        :checked="booleanValue"
        data-testid="kanban-workflow-contact-value-boolean"
        type="checkbox"
        class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
        @change="emit('update-boolean', $event)"
      />
      {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CONTACT_VALUE_ENABLED') }}
    </label>
    <label v-else class="grid gap-1 text-xs font-medium text-n-slate-11">
      {{ t('KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.CONTACT_VALUE') }}
      <input
        v-model="data.action_params.value"
        data-testid="kanban-workflow-contact-value"
        :type="isDate ? 'date' : 'text'"
        class="h-9 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
        @change="emit('update')"
      />
    </label>
  </section>
</template>
