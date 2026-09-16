<script setup>
import { useI18n } from 'vue-i18n';

defineProps({ current: { type: Number, required: true } });

const { t } = useI18n();
const STEPS = ['TIME', 'DETAILS', 'DONE'];
</script>

<template>
  <ol
    class="mb-0 flex list-none flex-wrap gap-1.5 p-0"
    :aria-label="t('PUBLIC_BOOKING.STEPS_LABEL')"
  >
    <li
      v-for="(step, index) in STEPS"
      :key="step"
      class="flex items-center gap-1.5 text-micro font-semibold uppercase tracking-wider"
      :class="index + 1 === current ? 'text-n-brand' : 'text-n-slate-10'"
      :aria-current="index + 1 === current ? 'step' : undefined"
    >
      <i
        class="grid size-[18px] place-items-center rounded-full border border-solid text-micro not-italic"
        :class="
          index + 1 === current
            ? 'border-n-brand bg-n-brand text-white'
            : 'border-n-strong bg-n-surface-2'
        "
        aria-hidden="true"
      >
        {{ index + 1 < current ? '✓' : index + 1 }}
      </i>
      {{ t(`PUBLIC_BOOKING.STEPS.${step}`) }}
    </li>
  </ol>
</template>
