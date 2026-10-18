<script setup>
/**
 * A grelha do Início editável — proposta A, aprovada a 18/10.
 *
 * Doze colunas, linhas de 4rem. Fora de edição é só uma grelha: nada de pegas,
 * contornos ou animação, e o Início continua a ser uma fila de trabalho limpa.
 * Em edição, cada bloco move-se e redimensiona-se por três caminhos que chegam
 * ao mesmo resultado: arrastar, botões do painel «Ajustar», e teclado.
 *
 * Arrastar só começa depois de 4px: abaixo disso é um clique, e o clique na
 * moldura não deve mexer em nada. Durante o arrasto desenha-se uma prévia já
 * encaixada — o que se vê ao largar é o que fica.
 *
 * Abaixo de 768px os blocos empilham-se numa coluna, pela ordem de leitura da
 * grelha. A edição fica para ecrãs de computador (quem chama esconde o botão).
 */
import { computed, nextTick, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMediaQuery } from '@vueuse/core';
import RaevoHomeWidget from './RaevoHomeWidget.vue';
import { GRID_COLUMNS, moveItem, resizeItem } from './raevoHomeLayout';

const props = defineProps({
  items: { type: Array, required: true },
  editing: { type: Boolean, default: false },
  // id → rótulo visível do bloco, para o nome acessível e para os anúncios.
  labels: { type: Object, required: true },
});

const emit = defineEmits(['update:items', 'remove', 'rename', 'add']);

const { t } = useI18n();
const wide = useMediaQuery('(min-width: 768px)');
const gridEl = ref(null);
const preview = ref(null);
const announcement = ref('');
const DRAG_THRESHOLD = 4;

const shown = computed(() => preview.value || props.items);
const bottom = computed(() =>
  Math.max(0, ...shown.value.map(item => item.y + item.h))
);

const placement = item =>
  wide.value
    ? {
        gridColumn: `${item.x + 1} / span ${item.w}`,
        gridRow: `${item.y + 1} / span ${item.h}`,
      }
    : undefined;

const labelFor = item => item.title || props.labels[item.id] || item.id;

const announce = (items, id) => {
  const item = items.find(other => other.id === id);
  if (!item) return;
  announcement.value = t('HOME.LAYOUT.POSITION', {
    name: labelFor(item),
    column: item.x + 1,
    row: item.y + 1,
    w: item.w,
    h: item.h,
  });
};

const refocus = async id => {
  await nextTick();
  gridEl.value?.querySelector(`[data-widget-id="${id}"]`)?.focus();
};

const commit = (items, id) => {
  emit('update:items', items);
  announce(items, id);
};

const onNudge = (item, { dx = 0, dy = 0, dw = 0, dh = 0 }) => {
  const items =
    dw || dh
      ? resizeItem(props.items, item.id, { w: item.w + dw, h: item.h + dh })
      : moveItem(props.items, item.id, { x: item.x + dx, y: item.y + dy });
  commit(items, item.id);
  if (!dw && !dh) refocus(item.id);
};

// O passo de uma célula, medido na hora: a largura da grelha muda com a janela
// e com a barra lateral aberta ou fechada.
const cellPitch = () => {
  const style = getComputedStyle(gridEl.value);
  const gap = parseFloat(style.columnGap) || 0;
  const row = parseFloat(style.gridAutoRows) || 0;
  const { width } = gridEl.value.getBoundingClientRect();
  return { x: (width + gap) / GRID_COLUMNS, y: row + gap };
};

const onDragStart = (event, item, mode) => {
  const start = { x: event.clientX, y: event.clientY };
  const pitch = cellPitch();
  let dragging = false;

  const onMove = moveEvent => {
    const dxPx = moveEvent.clientX - start.x;
    const dyPx = moveEvent.clientY - start.y;
    if (!dragging && Math.hypot(dxPx, dyPx) < DRAG_THRESHOLD) return;
    dragging = true;
    const dx = Math.round(dxPx / pitch.x);
    const dy = Math.round(dyPx / pitch.y);
    preview.value =
      mode === 'resize'
        ? resizeItem(props.items, item.id, { w: item.w + dx, h: item.h + dy })
        : moveItem(props.items, item.id, { x: item.x + dx, y: item.y + dy });
  };
  const onUp = () => {
    window.removeEventListener('pointermove', onMove);
    window.removeEventListener('pointerup', onUp);
    window.removeEventListener('pointercancel', onUp);
    if (dragging && preview.value) commit(preview.value, item.id);
    preview.value = null;
  };

  window.addEventListener('pointermove', onMove);
  window.addEventListener('pointerup', onUp);
  window.addEventListener('pointercancel', onUp);
};
</script>

<template>
  <div
    ref="gridEl"
    data-testid="home-grid"
    class="grid grid-cols-1 gap-4 md:auto-rows-[4rem] md:grid-cols-12"
  >
    <RaevoHomeWidget
      v-for="item in shown"
      :key="item.id"
      :item="item"
      :label="labelFor(item)"
      :editing="editing"
      :stacked="!wide"
      described-by="home-layout-instructions"
      :style="placement(item)"
      :class="{ 'z-10 opacity-90': preview && editing }"
      @drag-start="(event, mode) => onDragStart(event, item, mode)"
      @nudge="change => onNudge(item, change)"
      @remove="emit('remove', item.id)"
      @rename="title => emit('rename', item.id, title)"
    >
      <template #default="slotProps">
        <slot name="widget" :item="item" v-bind="slotProps" />
      </template>
    </RaevoHomeWidget>

    <!--
      O «+» é sempre o último, a toda a largura, logo abaixo do bloco mais baixo.
      Pontilhado, porque é um lugar e não um bloco.
    -->
    <button
      v-if="editing"
      type="button"
      data-testid="home-add-widget"
      class="flex min-h-24 flex-col items-center justify-center gap-1 rounded-xl border-2 border-dashed border-n-slate-7 text-sm font-medium text-n-slate-11 hover:border-n-brand hover:bg-n-alpha-2 hover:text-n-slate-12 focus:outline-none focus-visible:ring-2 focus-visible:ring-n-brand/40"
      :style="
        wide
          ? {
              gridColumn: `1 / span ${GRID_COLUMNS}`,
              gridRow: `${bottom + 1} / span 2`,
            }
          : undefined
      "
      @click="emit('add')"
    >
      <i class="i-lucide-plus size-6" aria-hidden="true" />
      {{ t('HOME.LAYOUT.ADD') }}
    </button>

    <p id="home-layout-instructions" class="sr-only">
      {{ t('HOME.LAYOUT.INSTRUCTIONS') }}
    </p>
    <p class="sr-only" aria-live="polite">{{ announcement }}</p>
  </div>
</template>
