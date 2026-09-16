<script setup>
// Interruptor de 34×20, com papel de switch e rótulo acessível.
const props = defineProps({
  modelValue: { type: Boolean, default: false },
  label: { type: String, required: true },
  disabled: { type: Boolean, default: false },
});

const emit = defineEmits(['update:modelValue']);

const toggle = () => {
  if (!props.disabled) emit('update:modelValue', !props.modelValue);
};
</script>

<template>
  <button
    type="button"
    role="switch"
    :aria-checked="modelValue ? 'true' : 'false'"
    :aria-label="label"
    :disabled="disabled"
    class="relative h-5 w-[34px] shrink-0 rounded-full outline-none transition-colors focus-visible:ring-2 focus-visible:ring-n-brand/40 disabled:cursor-not-allowed disabled:opacity-60"
    :class="modelValue ? 'bg-n-brand' : 'bg-n-slate-7'"
    @click="toggle"
  >
    <span
      class="absolute top-0.5 size-4 rounded-full bg-white transition-[left] duration-150"
      :class="modelValue ? 'left-4' : 'left-0.5'"
    />
  </button>
</template>
