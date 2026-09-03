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
// Entrar em edição destrói o botão que se acabou de carregar, e essa destruição
// dispara um `focusout` sem destino — que fechava a linha no mesmo instante em
// que ela abria. A linha abria e fechava-se a si própria.
const abrindo = ref(false);

const temValor = computed(() => String(props.value ?? '').trim().length > 0);

const abrir = async () => {
  if (props.disabled || editando.value) return;
  abrindo.value = true;
  editando.value = true;
  emit('open');
  await nextTick();
  raiz.value
    ?.querySelector('input, select, textarea')
    ?.focus({ preventScroll: true });
  abrindo.value = false;
};

const fechar = () => {
  if (!editando.value) return;
  editando.value = false;
  emit('close');
};

// Carregar no rótulo tira o foco do controlo por um instante antes de o
// navegador o devolver — e o `focusout` desse intervalo chega sem destino,
// indistinguível de um clique fora. Sem esta marca, clicar no próprio rótulo
// fechava o campo em vez de o focar.
const cliqueInterno = ref(false);

// Sair ao perder o foco para fora da linha — mas não ao andar entre o controlo
// e a sua própria mensagem de erro.
const aoSairFoco = event => {
  if (abrindo.value) return;
  if (cliqueInterno.value) return;
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
  <div
    ref="raiz"
    data-testid="raevo-field-row"
    @focusout="aoSairFoco"
    @mousedown="cliqueInterno = true"
    @mouseup="cliqueInterno = false"
  >
    <!--
      Edição: o mesmo campo do design system, mas na geometria em que a linha
      já se lia — rótulo à esquerda, controle à direita, mesma coluna e mesmo
      degrau de texto. `px-2` repete o recuo do botão de repouso para o rótulo
      não deslizar no instante em que o campo abre. Texto longo é a exceção:
      várias linhas não cabem ao lado, então continua empilhado.
    -->
    <div v-if="editando" class="px-2 py-1" @keydown="aoTeclar">
      <RaevoField
        :label="label"
        :variant="variant"
        :hint="hint"
        :error="error"
        :inline="variant !== 'textarea'"
      >
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
      <!--
        Rótulo e valor no mesmo degrau da escala. O valor desenhava a 14px e o
        rótulo a 12px: o valor pesava mais do que a pergunta a que responde, e a
        linha lia-se ao contrário. A hierarquia fica na cor, não no tamanho.
      -->
      <span class="text-sm leading-5 text-n-slate-11">
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
