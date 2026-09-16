<script setup>
// Botão das configurações, igual ao mockup: pílula, 13px/600. `dashed` é o
// «+ intervalo» e o «+ Acrescentar…», que ainda não é conteúdo.
defineProps({
  label: { type: String, required: true },
  variant: {
    type: String,
    default: 'secondary',
    validator: value => ['primary', 'secondary', 'dashed'].includes(value),
  },
  size: { type: String, default: 'md' },
  type: { type: String, default: 'button' },
  loading: { type: Boolean, default: false },
  disabled: { type: Boolean, default: false },
});
</script>

<template>
  <button
    :type="type"
    :disabled="disabled || loading"
    class="inline-flex items-center justify-center gap-1.5 whitespace-nowrap border border-solid font-semibold outline-none transition-colors focus-visible:ring-2 focus-visible:ring-n-brand/40 disabled:cursor-not-allowed disabled:opacity-60"
    :class="[
      variant === 'dashed'
        ? 'rounded-lg border-dashed border-n-strong bg-transparent px-[9px] py-[5px] text-xs font-normal text-n-slate-10 hover:text-n-slate-12'
        : 'rounded-full',
      variant === 'primary' &&
        'border-n-brand bg-n-brand text-white hover:bg-n-brand/90',
      variant === 'secondary' &&
        'border-n-strong bg-n-solid-1 text-n-slate-11 hover:text-n-slate-12',
      variant !== 'dashed' &&
        (size === 'sm' ? 'px-[11px] py-[5px] text-xs' : 'px-3.5 py-2 text-ui'),
    ]"
  >
    <i
      v-if="loading"
      class="i-lucide-loader-circle size-3.5 animate-spin"
      aria-hidden="true"
    />
    {{ label }}
  </button>
</template>
