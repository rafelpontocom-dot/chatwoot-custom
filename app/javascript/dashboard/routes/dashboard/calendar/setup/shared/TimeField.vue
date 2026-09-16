<script setup>
import { ref, watch } from 'vue';

// Hora em «HH:MM», sempre 24h. O campo de hora do browser mudava de formato com
// o idioma do sistema (AM/PM) e punha ícones que não cabem num intervalo.
const props = defineProps({
  modelValue: { type: String, default: '' },
  label: { type: String, required: true },
  disabled: { type: Boolean, default: false },
});

const emit = defineEmits(['update:modelValue']);
const text = ref(props.modelValue);

watch(
  () => props.modelValue,
  value => {
    text.value = value;
  }
);

// «8» → 08:00 · «830» → 08:30 · «18:5» → 18:05
const normalize = raw => {
  let hours;
  let minutes;
  if (raw.includes(':')) {
    const [h, m = '0'] = raw.split(':');
    hours = Number(h.replace(/\D/g, '') || NaN);
    minutes = Number(m.replace(/\D/g, '') || 0);
  } else {
    const digits = raw.replace(/\D/g, '').slice(0, 4);
    if (!digits) return null;
    hours = Number(digits.length <= 2 ? digits : digits.slice(0, -2));
    minutes = digits.length <= 2 ? 0 : Number(digits.slice(-2));
  }
  if (Number.isNaN(hours) || hours > 23 || minutes > 59) return null;
  return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;
};

const commit = () => {
  const value = normalize(text.value || '');
  if (!value) {
    text.value = props.modelValue;
    return;
  }
  text.value = value;
  if (value !== props.modelValue) emit('update:modelValue', value);
};
</script>

<template>
  <input
    v-model="text"
    type="text"
    inputmode="numeric"
    maxlength="5"
    :aria-label="label"
    :disabled="disabled"
    class="reset-base mb-0 w-[2.9rem] border-0 bg-transparent p-0 text-center text-xs tabular-nums text-n-slate-12 outline-none focus:rounded focus:ring-2 focus:ring-n-brand/30"
    @blur="commit"
    @keydown.enter.prevent="commit"
  />
</template>
