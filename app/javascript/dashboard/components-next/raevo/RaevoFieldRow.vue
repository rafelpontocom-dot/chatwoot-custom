<script setup>
import { computed, nextTick, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import RaevoField from './RaevoField.vue';

/**
 * Raevo — o campo que lê em linha e edita em campo.
 *
 * Ler e preencher são momentos diferentes e pagavam o mesmo preço. Rótulo em
 * cima é lido numa única fixação ocular (~50 ms de sacada, contra ~500 ms do
 * rótulo ao lado) e preenche quase 2× mais rápido — mas custa 62 px por campo,
 * o que deixava ~11 campos visíveis numa ficha que tem dezenas.
 *
 * A literatura abre exceção justamente para ficha densa de campos familiares,
 * que é o caso de quem preenche os mesmos 12 campos 40 vezes por dia. Então:
 * em repouso a linha é compacta e sem vão entre rótulo e valor; ao editar, vira
 * o `RaevoField` inteiro, com rótulo em cima e a geometria do design system.
 */
const props = defineProps({
  label: { type: String, required: true },
  /** Texto mostrado em repouso. Vazio vira traço, nunca espaço em branco. */
  value: { type: String, default: '' },
  variant: {
    type: String,
    default: 'input',
    validator: v => ['input', 'select', 'textarea'].includes(v),
  },
  hint: { type: String, default: '' },
  error: { type: String, default: '' },
  disabled: { type: Boolean, default: false },
  /** identifica esta linha; o control mantém o seu próprio data-testid */
  rowTestid: { type: String, default: 'raevo-field-row-read' },
});

const emit = defineEmits(['open', 'close']);
const { t } = useI18n();

const editando = ref(false);
const raiz = ref(null);

const temValor = computed(() => String(props.value ?? '').trim().length > 0);

const abrir = async () => {
  if (props.disabled || editando.value) return;
  editando.value = true;
  emit('open');
  await nextTick();
  raiz.value
    ?.querySelector('input, select, textarea')
    ?.focus({ preventScroll: true });
};

const fechar = () => {
  if (!editando.value) return;
  editando.value = false;
  emit('close');
};

// Sair ao perder o foco para fora da linha — mas não ao andar entre o controlo
// e a sua própria mensagem de erro.
const aoSairFoco = event => {
  if (raiz.value?.contains(event.relatedTarget)) return;
  fechar();
};

const aoTeclar = event => {
  if (event.key === 'Escape') {
    event.stopPropagation();
    fechar();
    return;
  }
  if (event.key === 'Enter' && props.variant !== 'textarea') {
    event.preventDefault();
    fechar();
  }
};

defineExpose({ abrir, fechar });
</script>

<template>
  <div ref="raiz" data-testid="raevo-field-row" @focusout="aoSairFoco">
    <!-- Edição: o campo completo do design system, rótulo em cima -->
    <div v-if="editando" class="py-1" @keydown="aoTeclar">
      <RaevoField :label="label" :variant="variant" :hint="hint" :error="error">
        <template #default="slotProps">
          <slot name="control" v-bind="slotProps" />
        </template>
      </RaevoField>
    </div>

    <!-- Repouso: uma linha, sem vão entre rótulo e valor -->
    <button
      v-else
      type="button"
      :data-testid="rowTestid"
      :disabled="disabled"
      class="grid min-h-8 w-full grid-cols-[8.75rem_minmax(0,1fr)] items-start gap-3 rounded-lg px-2 py-1.5 text-left outline-none hover:bg-n-alpha-1 focus-visible:ring-2 focus-visible:ring-n-brand disabled:cursor-not-allowed disabled:opacity-60"
      :aria-label="t('RAEVO.FIELD_ROW.EDIT', { field: label })"
      @click="abrir"
    >
      <span class="pt-0.5 text-xs leading-5 text-n-slate-11">
        {{ label }}
      </span>
      <span
        class="min-w-0 break-words text-sm leading-5"
        :class="temValor ? 'text-n-slate-12' : 'text-n-slate-9'"
      >
        {{ temValor ? value : t('RAEVO.FIELD_ROW.EMPTY') }}
      </span>
    </button>
  </div>
</template>
