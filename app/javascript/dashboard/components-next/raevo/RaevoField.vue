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
  /**
   * Rótulo à esquerda, controle à direita, na mesma linha.
   *
   * Numa ficha densa que se lê em linha, empilhar só ao editar reescreve a
   * geometria debaixo do cursor: o rótulo encolhe de 14px para 12px e o campo
   * salta para baixo dele. Em linha, abrir o campo não move mais nada.
   * Texto longo continua empilhado — várias linhas não cabem ao lado.
   */
  inline: {
    type: Boolean,
    default: false,
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
  <div
    class="grid"
    :class="
      inline
        ? 'grid-cols-[8.75rem_minmax(0,1fr)] items-center gap-x-3 gap-y-1'
        : 'gap-1.5'
    "
  >
    <!--
      Rótulo mais leve que o título de seção: sem essa diferença os dois pesam
      igual e a hierarquia do painel desaparece. Em linha ele mantém o degrau
      do texto ao lado — encolher só ao editar era o salto que se via.
    -->
    <label
      v-if="label"
      :for="fieldId"
      :class="
        inline
          ? 'text-sm leading-5 text-n-slate-11'
          : 'text-xs font-medium leading-4 text-n-slate-11'
      "
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

    <!-- Em linha, mensagem e dica alinham com o controle, não com o rótulo -->
    <p
      v-if="error"
      :id="`${fieldId}-error`"
      :data-testid="errorTestid"
      class="mb-0 text-xs text-n-ruby-11"
      :class="inline && 'col-start-2'"
      role="alert"
    >
      {{ error }}
    </p>
    <p
      v-else-if="hint"
      :id="`${fieldId}-hint`"
      class="mb-0 text-xs text-n-slate-11"
      :class="inline && 'col-start-2'"
    >
      {{ hint }}
    </p>
  </div>
</template>
