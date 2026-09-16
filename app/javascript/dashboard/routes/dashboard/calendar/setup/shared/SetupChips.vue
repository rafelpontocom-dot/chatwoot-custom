<script setup>
import { computed } from 'vue';

// Chips com aria-pressed. `multiple` alterna cada chip; sem ele, é uma escolha só.
const props = defineProps({
  modelValue: { type: [String, Number, Boolean, Array], default: null },
  options: { type: Array, required: true },
  multiple: { type: Boolean, default: false },
  label: { type: String, default: '' },
  disabled: { type: Boolean, default: false },
});

const emit = defineEmits(['update:modelValue']);

const selected = computed(() =>
  props.multiple ? props.modelValue || [] : [props.modelValue]
);

const isPressed = option => selected.value.includes(option.value);

const toggle = option => {
  if (props.disabled || option.disabled) return;
  if (!props.multiple) {
    emit('update:modelValue', option.value);
    return;
  }
  const next = isPressed(option)
    ? selected.value.filter(value => value !== option.value)
    : [...selected.value, option.value];
  emit('update:modelValue', next);
};
</script>

<template>
  <span class="flex flex-wrap gap-1.5" role="group" :aria-label="label">
    <button
      v-for="option in options"
      :key="String(option.value)"
      type="button"
      class="rounded-full border border-solid px-[11px] py-[5px] text-xs outline-none transition-colors focus-visible:ring-2 focus-visible:ring-n-brand/40 disabled:cursor-not-allowed disabled:opacity-60"
      :class="
        isPressed(option)
          ? 'border-n-brand bg-n-brand/10 font-semibold text-n-brand'
          : 'border-n-strong bg-n-solid-1 text-n-slate-11 hover:border-n-slate-8'
      "
      :aria-pressed="isPressed(option) ? 'true' : 'false'"
      :disabled="disabled || option.disabled"
      :title="option.title"
      :data-testid="option.testid"
      @click="toggle(option)"
    >
      {{ option.label }}
    </button>
  </span>
</template>
