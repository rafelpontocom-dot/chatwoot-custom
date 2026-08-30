<script setup>
/**
 * Raevo · Sereno — selo de estado.
 *
 * Existe para tornar estrutural uma regra de acessibilidade: estado NUNCA se
 * comunica só por cor. Este componente sempre renderiza cor + ícone + texto.
 * Se você está escrevendo um `<span class="rounded-full bg-n-teal-3">` para
 * mostrar situação, use isto no lugar.
 *
 * Ver docs/raevo-design-system.md §2 e §6.
 */
import Icon from 'next/icon/Icon.vue';

const props = defineProps({
  /** neutral | success | warning | danger | info */
  variant: {
    type: String,
    default: 'neutral',
    validator: v =>
      ['neutral', 'success', 'warning', 'danger', 'info'].includes(v),
  },
  /** Texto do selo. Obrigatório: sem rótulo o estado vira cor sozinha. */
  label: { type: String, required: true },
  /** Ícone. Cada variante tem um padrão sensato; sobrescreva se precisar. */
  icon: { type: String, default: '' },
  size: {
    type: String,
    default: 'md',
    validator: v => ['sm', 'md'].includes(v),
  },
});

const TONES = {
  neutral: 'bg-n-slate-3 text-n-slate-11',
  success: 'bg-n-teal-3 text-n-teal-11',
  warning: 'bg-n-amber-3 text-n-amber-11',
  danger: 'bg-n-ruby-3 text-n-ruby-11',
  info: 'bg-n-blue-3 text-n-blue-11',
};

const ICONS = {
  neutral: 'i-lucide-circle-dashed',
  success: 'i-lucide-check',
  warning: 'i-lucide-clock',
  danger: 'i-lucide-alert-triangle',
  info: 'i-lucide-info',
};

const SIZES = {
  sm: 'px-2 py-0.5 text-micro gap-1',
  md: 'px-2.5 py-1 text-xs gap-1.5',
};
</script>

<template>
  <span
    class="inline-flex w-fit items-center rounded-full font-medium"
    :class="[TONES[props.variant], SIZES[props.size]]"
  >
    <Icon
      :icon="props.icon || ICONS[props.variant]"
      class="shrink-0"
      :class="props.size === 'sm' ? 'size-3' : 'size-3.5'"
    />
    <span>{{ props.label }}</span>
  </span>
</template>
