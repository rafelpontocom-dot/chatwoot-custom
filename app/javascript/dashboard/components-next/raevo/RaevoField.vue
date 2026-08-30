<script setup>
import { computed, useId } from 'vue';
import {
  RAEVO_CONTROL_CLASS,
  RAEVO_SELECT_CLASS,
  RAEVO_TEXTAREA_CLASS,
} from './raevoControl';

/**
 * Raevo — campo de formulário.
 *
 * Rótulo acima, campo abaixo, ambos na mesma borda esquerda. O slot recebe a
 * classe pronta e o id, então nenhuma tela precisa reescrever a aparência do
 * controle — que foi exatamente como o produto acumulou três tratamentos
 * diferentes de campo dentro do mesmo diálogo.
 */
const props = defineProps({
  label: {
    type: String,
    default: '',
  },
  hint: {
    type: String,
    default: '',
  },
  error: {
    type: String,
    default: '',
  },
  required: {
    type: Boolean,
    default: false,
  },
  /** 'input' | 'select' | 'textarea' — só muda a casca, nunca o alinhamento */
  variant: {
    type: String,
    default: 'input',
    validator: value => ['input', 'select', 'textarea'].includes(value),
  },
  /** data-testid do parágrafo de erro, para specs que já o localizavam */
  errorTestid: {
    type: String,
    default: undefined,
  },
});

const fieldId = useId();

const controlClass = computed(() => {
  if (props.variant === 'select') return RAEVO_SELECT_CLASS;
  if (props.variant === 'textarea') return RAEVO_TEXTAREA_CLASS;
  return RAEVO_CONTROL_CLASS;
});

const describedBy = computed(() => {
  if (props.error) return `${fieldId}-error`;
  if (props.hint) return `${fieldId}-hint`;
  return undefined;
});
</script>

<template>
  <div class="grid gap-1.5">
    <!--
      Rótulo mais leve que o título de seção: sem essa diferença os dois pesam
      igual e a hierarquia do painel desaparece.
    -->
    <label
      v-if="label"
      :for="fieldId"
      class="text-xs font-medium leading-4 text-n-slate-11"
    >
      {{ label }}
      <span
        v-if="required"
        aria-hidden="true"
        class="text-n-ruby-11 after:content-['*']"
      />
    </label>

    <div class="relative">
      <slot
        :control-class="controlClass"
        :field-id="fieldId"
        :described-by="describedBy"
      />
      <i
        v-if="variant === 'select'"
        aria-hidden="true"
        class="i-lucide-chevron-down pointer-events-none absolute right-3 top-1/2 size-4 -translate-y-1/2 text-n-slate-10"
      />
    </div>

    <p
      v-if="error"
      :id="`${fieldId}-error`"
      :data-testid="errorTestid"
      class="mb-0 text-xs text-n-ruby-11"
      role="alert"
    >
      {{ error }}
    </p>
    <p
      v-else-if="hint"
      :id="`${fieldId}-hint`"
      class="mb-0 text-xs text-n-slate-11"
    >
      {{ hint }}
    </p>
  </div>
</template>
