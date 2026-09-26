<script setup>
/**
 * Raevo · A · Consultório — histórico em trilho.
 *
 * A anatomia do sistema aprovado: um trilho de 1px com um ponto por evento, o
 * que aconteceu em cima e quando embaixo. O trilho não desenha depois do último
 * ponto — uma linha a sair do fim sugere que falta carregar mais.
 *
 * Existe porque o histórico aparece em dois sítios da mesma ficha — os últimos
 * eventos ao lado do contexto, e a lista inteira no separador — e dois sítios
 * com a mesma informação em formatos diferentes é como o produto acumulou três
 * tratamentos de tudo.
 *
 * O ponto tem cor, mas a cor é redundante: o que o evento é está escrito no
 * título. É a regra 5 ao contrário — aqui a cor acompanha o texto, não o
 * substitui, e por isso não precisa de ícone.
 */
const props = defineProps({
  /**
   * `[{ id, title, meta, tone }]`. `tone` é opcional e só pinta o ponto:
   * neutral (omissão) · success · warning · danger · info.
   */
  items: { type: Array, required: true },
});

const PONTOS = {
  neutral: 'bg-n-slate-10',
  success: 'bg-n-teal-9',
  warning: 'bg-n-amber-9',
  danger: 'bg-n-ruby-9',
  info: 'bg-n-blue-9',
};

const pontoDe = tone => PONTOS[tone] || PONTOS.neutral;
</script>

<template>
  <ol class="grid list-none p-0">
    <li
      v-for="(item, indice) in props.items"
      :key="item.id"
      class="relative grid grid-cols-[0.9375rem_minmax(0,1fr)] items-start gap-2 pb-3 last:pb-0"
    >
      <!-- o trilho: começa depois do ponto e não desenha no último item -->
      <span
        v-if="indice < props.items.length - 1"
        aria-hidden="true"
        class="absolute bottom-0 left-[0.4375rem] top-4 w-px bg-n-weak"
      />
      <span
        aria-hidden="true"
        class="z-10 grid size-[0.9375rem] place-items-center rounded-full bg-n-surface-2"
      >
        <span class="size-1.5 rounded-full" :class="pontoDe(item.tone)" />
      </span>
      <span class="grid min-w-0 gap-0.5">
        <span class="break-words text-sm font-medium text-n-slate-12">
          {{ item.title }}
        </span>
        <span v-if="item.meta" class="break-words text-xs text-n-slate-10">
          {{ item.meta }}
        </span>
        <slot name="extra" :item="item" />
      </span>
    </li>
  </ol>
</template>
