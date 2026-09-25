<script setup>
/**
 * Raevo · A · Consultório — cartão de indicador.
 *
 * É a peça mais repetida do sistema aprovado: seis das oito telas abrem com uma
 * fila de quatro. Existe porque a anatomia dela não é obvia e cada tela que a
 * escrevia à mão inventava a sua — foi assim que o produto acumulou três
 * tratamentos de cartão de número.
 *
 * A anatomia vem do `CardHeader` da referência, e a ordem importa:
 *
 *   1. o RÓTULO primeiro, pequeno — o que se está a medir
 *   2. a AÇÃO no canto, segunda coluna da grelha, só se houver
 *   3. o NÚMERO grande com a VARIAÇÃO ao lado
 *   4. o RODAPÉ separado por um filete — o contexto que explica o número
 *
 * Não é um empilhado de três linhas: a grelha abre a segunda coluna só quando
 * `to` ou o slot `action` existem, como na referência.
 *
 * A variação é `RaevoStamp`, não um `<span>` colorido: a regra 5 diz que estado
 * não se comunica só por cor, e subir ou descer é estado. Daí vir sempre com
 * seta e com texto.
 *
 * O número usa `tabular-nums` e não parte: numa fila de quatro, dígitos de
 * larguras diferentes fazem os cartões dançarem quando os dados mudam.
 */
import { computed } from 'vue';
import { RouterLink } from 'vue-router';
import RaevoStamp from './RaevoStamp.vue';

const props = defineProps({
  /** O que se está a medir. «Valor em funil», «Ações vencidas». */
  label: { type: String, required: true },
  /**
   * O número, já formatado. Formatar é do chamador: só ele sabe se são reais,
   * euros, dias ou uma percentagem.
   */
  value: { type: [String, Number], required: true },
  /**
   * A variação, já formatada — «+12%», «-2d». Vazio esconde o selo.
   * Um indicador sem histórico ainda é um indicador; não se inventa um delta.
   */
  delta: { type: String, default: '' },
  /**
   * Se a variação é boa. Não é o sinal do número: em «Ações vencidas» e em
   * «Custo por lead», descer é bom. Quem chama sabe, o cartão não.
   */
  deltaIsGood: { type: Boolean, default: true },
  /** O contexto sob o filete. «R$ 54,7k no mês passado», «4 cobranças». */
  footer: { type: String, default: '' },
  /** Para onde o canto leva. Sem isto, a segunda coluna não abre. */
  to: { type: [String, Object], default: null },
  /** Rótulo acessível do canto — obrigatório com `to`: é controlo só de ícone. */
  toLabel: { type: String, default: '' },
});

// Sem valor ainda medido, mostra-se o travessão. Um zero mentiria, e um cartão
// em branco desalinharia a fila.
const display = computed(() =>
  props.value === null || props.value === undefined || props.value === ''
    ? '—'
    : props.value
);
</script>

<template>
  <div
    class="grid grid-cols-[1fr_auto] items-start gap-1 rounded-xl border border-solid border-n-weak bg-n-solid-1 p-card"
  >
    <p class="col-start-1 text-xs text-n-slate-10">{{ label }}</p>

    <RouterLink
      v-if="to"
      :to="to"
      :aria-label="toLabel"
      :title="toLabel"
      class="col-start-2 row-start-1 flex size-icon items-center justify-center rounded-sm text-n-slate-10 outline-none hover:text-n-slate-12 focus-visible:ring-2 focus-visible:ring-n-brand/40"
    >
      <span class="i-lucide-arrow-up-right size-icon" />
    </RouterLink>
    <span v-else-if="$slots.action" class="col-start-2 row-start-1">
      <slot name="action" />
    </span>

    <div class="col-start-1 flex flex-wrap items-center gap-control-gap">
      <span
        class="whitespace-nowrap text-3xl font-semibold tracking-tight tabular-nums text-n-slate-12"
      >
        {{ display }}
      </span>
      <RaevoStamp
        v-if="delta"
        size="sm"
        :variant="deltaIsGood ? 'success' : 'danger'"
        :icon="deltaIsGood ? 'i-lucide-arrow-up' : 'i-lucide-arrow-down'"
        :label="delta"
      />
    </div>

    <p
      v-if="footer"
      class="col-start-1 border-t border-solid border-n-weak pt-cell text-xs text-n-slate-10"
    >
      {{ footer }}
    </p>
  </div>
</template>
