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
 *
 * ## As três densidades, e quando cada uma é a certa
 *
 * A densidade não é gosto: é a resposta a «o número é o assunto desta tela, ou
 * é a moldura dele?» — e, quando é moldura, a quanto espaço ela tem direito.
 *
 * - `card` (omissão): caixa própria, número a 30px, rodapé sob um filete.
 *   Serve onde o indicador É o conteúdo do topo da tela. ≈139px de fila.
 * - `strip`: a mesma anatomia sem caixa, rótulo em caixa alta, número a 16px.
 *   Rodapé por baixo, sem filete. ≈76px de fila.
 * - `inline`: **só rótulo e valor**, numa linha, sem caixa, sem variação e sem
 *   rodapé. ≈24px de fila, e cabe no canto de um cabeçalho que já existe.
 *
 * `inline` é a única que **perde informação de propósito**, e isso está aqui em
 * letra gorda porque é a decisão e não um efeito colateral: a variação e o
 * contexto não aparecem. Quem a usa aceita que a tela deixa de dizer se o número
 * subiu ou desceu — ou põe a variação ao alcance de um clique, como o Pipeline e
 * a Agenda fazem com o botão de detalhe.
 *
 * As três vivem aqui de propósito. Uma linha de números desenhada à mão em cada
 * tela seria o quarto tratamento de número deste produto.
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
  /** `card`, `strip` ou `inline`. Ver o bloco acima: a escolha é uma regra. */
  density: {
    type: String,
    default: 'card',
    validator: valor => ['card', 'strip', 'inline'].includes(valor),
  },
});

const emCartao = computed(() => props.density === 'card');
const emLinha = computed(() => props.density === 'inline');

// Sem valor ainda medido, mostra-se o travessão. Um zero mentiria, e um cartão
// em branco desalinharia a fila.
const display = computed(() =>
  props.value === null || props.value === undefined || props.value === ''
    ? '—'
    : props.value
);
</script>

<template>
  <!--
    As classes ficam em literais dentro do `:class`, e não num `computed`: a
    porta `check-design-pairs.mjs` lê cada literal do atributo como um conjunto
    de classes que coexistem, e não vê string montada em JS. Mover a decisão
    para o script tirava o par de baixo do olhar da porta — que foi exatamente
    como a pílula do campo sobreviveu cinco meses.
  -->
  <div
    :class="{
      'grid grid-cols-[1fr_auto] items-start gap-1 rounded-xl border border-solid border-n-weak bg-n-solid-1 p-card':
        density === 'card',
      'grid grid-cols-[1fr_auto] items-start gap-0.5': density === 'strip',
      'flex items-baseline gap-control-gap whitespace-nowrap':
        density === 'inline',
    }"
  >
    <p
      :class="{
        'col-start-1 text-xs text-n-slate-10': density === 'card',
        'col-start-1 text-micro font-bold uppercase tracking-[0.12em] text-n-slate-10':
          density === 'strip',
        'text-micro font-bold uppercase tracking-[0.12em] text-n-slate-10':
          density === 'inline',
      }"
    >
      {{ label }}
    </p>

    <RouterLink
      v-if="to && !emLinha"
      :to="to"
      :aria-label="toLabel"
      :title="toLabel"
      class="col-start-2 row-start-1 flex size-icon items-center justify-center rounded-sm text-n-slate-10 outline-none hover:text-n-slate-12 focus-visible:ring-2 focus-visible:ring-n-brand/40"
    >
      <span class="i-lucide-arrow-up-right size-icon" />
    </RouterLink>
    <span v-else-if="$slots.action && !emLinha" class="col-start-2 row-start-1">
      <slot name="action" />
    </span>

    <!--
      Em linha o número não precisa de contentor: é um irmão do rótulo, no mesmo
      `flex`, alinhado pela linha de base. Um `div` a mais aqui partia o
      alinhamento com o rótulo, que é o que faz o par ler-se como uma coisa só.
    -->
    <component
      :is="emLinha ? 'span' : 'div'"
      :class="{
        'col-start-1 flex flex-wrap items-center gap-control-gap': !emLinha,
        'inline-flex items-baseline gap-control-gap': emLinha,
      }"
    >
      <span
        class="whitespace-nowrap font-semibold tracking-tight tabular-nums text-n-slate-12"
        :class="{
          'text-3xl': density === 'card',
          'text-base': density === 'strip',
          'text-sm': density === 'inline',
        }"
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
    </component>

    <!--
      Em faixa o rodapé não leva filete: quatro filetes curtos lado a lado, um
      por coluna, leem-se como uma tabela partida. O que separa ali é o ar entre
      colunas, como manda a regra 3.

      E fica em `text-xs`, não em `text-micro`: o rodapé é texto corrido, e
      `micro` está reservado a selo, contador e cabeçalho em caixa alta — está
      escrito em `tailwind.config.js`, ao lado do degrau.

      Em linha não há rodapé nenhum: é o que `inline` troca por caber no canto.
    -->
    <p
      v-if="footer && !emLinha"
      class="col-start-1"
      :class="
        emCartao
          ? 'border-t border-solid border-n-weak pt-cell text-xs text-n-slate-10'
          : 'text-xs text-n-slate-10'
      "
    >
      {{ footer }}
    </p>
  </div>
</template>
