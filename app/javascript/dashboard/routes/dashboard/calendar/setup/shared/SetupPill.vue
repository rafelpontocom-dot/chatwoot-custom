<script setup>
// Selo de estado. Leva sempre texto; os tons de aviso e de integração levam
// também ícone, porque estado não se comunica só por cor.
const props = defineProps({
  label: { type: String, required: true },
  tone: {
    type: String,
    default: 'neutral',
    validator: value =>
      ['neutral', 'on', 'google', 'feegow', 'warn'].includes(value),
  },
});

const TONES = {
  neutral: 'border-n-strong text-n-slate-11',
  on: 'border-transparent bg-n-brand/10 text-n-brand',
  google: 'border-transparent bg-n-teal-3 text-n-teal-11',
  feegow: 'border-transparent bg-n-violet-3 text-n-violet-11',
  warn: 'border-transparent bg-n-amber-3 text-n-amber-11',
};

const ICONS = {
  google: 'i-lucide-calendar',
  feegow: 'i-lucide-stethoscope',
  warn: 'i-lucide-triangle-alert',
};

const toneClass = TONES[props.tone];
const icon = ICONS[props.tone];
</script>

<template>
  <span
    class="inline-flex items-center gap-1 whitespace-nowrap rounded-full border border-solid px-[9px] py-[3px] text-micro font-semibold"
    :class="toneClass"
  >
    <i v-if="icon" :class="icon" class="size-3" aria-hidden="true" />
    {{ label }}
  </span>
</template>
