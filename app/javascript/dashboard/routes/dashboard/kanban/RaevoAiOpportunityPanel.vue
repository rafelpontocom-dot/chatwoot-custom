<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

import RaevoStamp from 'dashboard/components-next/raevo/RaevoStamp.vue';
import {
  displayRaevoAiEnumValue,
  displayRaevoAiFieldLabel,
  displayRaevoAiFieldValue,
  displayRaevoAiSummary,
} from './raevoAiOpportunityDisplay';

const props = defineProps({
  fields: {
    type: Array,
    default: () => [],
  },
  values: {
    type: Object,
    default: () => ({}),
  },
});

const { t, locale } = useI18n();

const summaryField = computed(() =>
  props.fields.find(field => field.key === 'raevo_ai_summary')
);
const detailFields = computed(() =>
  props.fields.filter(
    field => !['raevo_ai_summary', 'raevo_ai_status'].includes(field.key)
  )
);
const statusValue = computed(() =>
  String(props.values.raevo_ai_status || '').trim()
);
const statusVariant = computed(() => {
  if (['qualificado', 'agendado'].includes(statusValue.value)) {
    return 'success';
  }
  if (['pre_agendado', 'em_atendimento'].includes(statusValue.value)) {
    return 'info';
  }
  if (['handoff_humano', 'bloqueado'].includes(statusValue.value)) {
    return 'danger';
  }

  return 'neutral';
});

const isBlank = value =>
  value === null || value === undefined || String(value).trim() === '';
const displayLabel = field => displayRaevoAiFieldLabel(t, field);
const displayEnumValue = value => displayRaevoAiEnumValue(t, value);
const displaySummary = value => displayRaevoAiSummary(t, value);
const displayValue = field => {
  const value = props.values[field.key];
  return displayRaevoAiFieldValue({
    t,
    locale: locale.value,
    field,
    value,
    emptyValue: t('RAEVO_AI.OPPORTUNITY.EMPTY_VALUE'),
  });
};
</script>

<template>
  <section
    data-testid="raevo-ai-opportunity-panel"
    class="grid min-w-0 gap-5"
    :aria-label="t('RAEVO_AI.OPPORTUNITY.PANEL_LABEL')"
  >
    <div
      data-testid="raevo-ai-opportunity-summary"
      class="grid gap-2 border-b border-n-weak pb-4"
    >
      <div class="flex flex-wrap items-center justify-between gap-3">
        <h3 class="mb-0 text-sm font-semibold text-n-slate-12">
          {{
            summaryField
              ? displayLabel(summaryField)
              : t('RAEVO_AI.OPPORTUNITY.SUMMARY')
          }}
        </h3>
        <RaevoStamp
          v-if="statusValue"
          :label="displayEnumValue(statusValue)"
          :variant="statusVariant"
          size="sm"
        />
      </div>
      <p class="mb-0 whitespace-pre-wrap text-sm leading-6 text-n-slate-11">
        {{
          isBlank(values.raevo_ai_summary)
            ? t('RAEVO_AI.OPPORTUNITY.SUMMARY_EMPTY')
            : displaySummary(values.raevo_ai_summary)
        }}
      </p>
    </div>

    <dl class="grid gap-x-6 gap-y-4 sm:grid-cols-2">
      <div v-for="field in detailFields" :key="field.key" class="grid gap-1">
        <dt
          class="text-micro font-medium uppercase tracking-wide text-n-slate-10"
        >
          {{ displayLabel(field) }}
        </dt>
        <dd class="m-0 break-words text-sm text-n-slate-12">
          {{ displayValue(field) }}
        </dd>
      </div>
    </dl>
  </section>
</template>
