<script setup>
/**
 * A moldura de um bloco do Início editável.
 *
 * Mede o espaço que tem e diz ao conteúdo em que degrau está (`tier`). O
 * conteúdo acompanha o tamanho — pedido de 18/10 — mas em degraus da escala
 * tipográfica, não em zoom contínuo: a regra 6 do design system não deixa
 * inventar tamanhos, e um número que cresce aos píxeis acaba cortado.
 *
 *   sm  ·  número text-xl,  lista em text-xs
 *   md  ·  número text-3xl, lista em text-sm (o Início de antes)
 *   lg  ·  número text-display, lista em text-base
 *
 * Em edição, a moldura é o que se agarra: o conteúdo fica `inert` (não se
 * clica numa conversa enquanto se arruma), e aparecem a pega, o ×, o canto de
 * redimensionar e o painel «Ajustar». O painel é a alternativa a arrastar que
 * a WCAG 2.2 (2.5.7) exige: mover e redimensionar com um clique por passo.
 */
import { computed, nextTick, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useElementSize } from '@vueuse/core';
import RaevoField from '../RaevoField.vue';

const props = defineProps({
  item: { type: Object, required: true },
  label: { type: String, required: true },
  editing: { type: Boolean, default: false },
  // Empilhado (telemóvel): a altura vem do conteúdo, logo não há degrau a medir.
  stacked: { type: Boolean, default: false },
  describedBy: { type: String, default: '' },
});

const emit = defineEmits(['dragStart', 'nudge', 'remove', 'rename']);

const { t } = useI18n();
const root = ref(null);
const adjustButton = ref(null);
const { width, height } = useElementSize(root);

// Os limiares são os da proposta aprovada: «normal» a partir de ~3 × 2
// células, «amplo» a partir de ~5 × 3. Medidos em px porque é o que o
// ResizeObserver devolve; as células têm 4rem de altura e 1rem de intervalo.
const TIER_LG = { w: 352, h: 208 };
const TIER_MD = { w: 208, h: 136 };
const tier = computed(() => {
  if (props.stacked) return 'md';
  if (width.value >= TIER_LG.w && height.value >= TIER_LG.h) return 'lg';
  if (width.value >= TIER_MD.w && height.value >= TIER_MD.h) return 'md';
  return 'sm';
});

const adjusting = ref(false);
const closeAdjust = async () => {
  adjusting.value = false;
  await nextTick();
  adjustButton.value?.focus();
};

const KEY_STEPS = {
  ArrowLeft: [-1, 0],
  ArrowRight: [1, 0],
  ArrowUp: [0, -1],
  ArrowDown: [0, 1],
};

// Setas movem uma célula; Shift + setas mudam o tamanho. Só quando o foco
// está na própria moldura — dentro do painel as setas são do campo de texto.
const onKeydown = event => {
  if (!props.editing || event.target !== root.value) return;
  const step = KEY_STEPS[event.key];
  if (!step) return;
  event.preventDefault();
  const [dx, dy] = step;
  emit('nudge', event.shiftKey ? { dw: dx, dh: dy } : { dx, dy });
};

// O clique na pega ou no × não começa um arrasto; o resto da moldura sim.
const onPointerdown = event => {
  if (!props.editing || event.button !== 0) return;
  if (event.target.closest('button, input, [data-adjust-panel]')) return;
  emit('dragStart', event, 'move');
};

const MOVES = [
  { key: 'UP', icon: 'i-lucide-arrow-up', change: { dy: -1 } },
  { key: 'DOWN', icon: 'i-lucide-arrow-down', change: { dy: 1 } },
  { key: 'LEFT', icon: 'i-lucide-arrow-left', change: { dx: -1 } },
  { key: 'RIGHT', icon: 'i-lucide-arrow-right', change: { dx: 1 } },
];
const SIZES = [
  { key: 'NARROWER', icon: 'i-lucide-chevrons-right-left', change: { dw: -1 } },
  { key: 'WIDER', icon: 'i-lucide-chevrons-left-right', change: { dw: 1 } },
  { key: 'SHORTER', icon: 'i-lucide-chevrons-down-up', change: { dh: -1 } },
  { key: 'TALLER', icon: 'i-lucide-chevrons-up-down', change: { dh: 1 } },
];

defineExpose({ focus: () => root.value?.focus() });
</script>

<template>
  <div
    ref="root"
    :data-widget-id="item.id"
    :tabindex="editing ? 0 : undefined"
    :role="editing ? 'group' : undefined"
    :aria-label="editing ? label : undefined"
    :aria-describedby="editing && describedBy ? describedBy : undefined"
    class="relative h-full min-h-0 min-w-0 rounded-xl"
    :class="{
      'cursor-grab touch-none select-none outline outline-2 outline-offset-2 outline-dashed outline-n-slate-7 focus-visible:outline focus-visible:outline-n-brand':
        editing,
    }"
    @keydown="onKeydown"
    @pointerdown="onPointerdown"
  >
    <div class="h-full min-h-0" :inert="editing || undefined">
      <slot :tier="tier" :width="width" :height="height" :stacked="stacked" />
    </div>

    <template v-if="editing">
      <div
        class="absolute end-2 top-2 flex items-center gap-0.5 rounded-lg border border-solid border-n-weak bg-n-solid-1 p-0.5"
      >
        <button
          ref="adjustButton"
          type="button"
          data-testid="home-widget-adjust"
          class="inline-flex size-7 items-center justify-center rounded-lg text-n-slate-11 hover:bg-n-alpha-2 focus:outline-none focus-visible:ring-2 focus-visible:ring-n-brand/40"
          :aria-label="t('HOME.LAYOUT.ADJUST', { name: label })"
          :title="t('HOME.LAYOUT.ADJUST', { name: label })"
          :aria-expanded="adjusting"
          @click="adjusting = !adjusting"
        >
          <i class="i-lucide-move size-4" aria-hidden="true" />
        </button>
        <button
          type="button"
          data-testid="home-widget-remove"
          class="inline-flex size-7 items-center justify-center rounded-lg text-n-slate-11 hover:bg-n-alpha-2 focus:outline-none focus-visible:ring-2 focus-visible:ring-n-brand/40"
          :aria-label="t('HOME.LAYOUT.REMOVE', { name: label })"
          :title="t('HOME.LAYOUT.REMOVE', { name: label })"
          @click="emit('remove')"
        >
          <i class="i-lucide-x size-4" aria-hidden="true" />
        </button>
      </div>

      <div
        v-if="adjusting"
        data-adjust-panel
        class="absolute end-2 top-11 z-10 grid w-64 gap-3 rounded-xl border border-solid border-n-weak bg-n-solid-1 p-3 shadow-lg"
        @keydown.esc.stop="closeAdjust"
      >
        <RaevoField :label="t('HOME.LAYOUT.NAME')">
          <template #default="{ controlClass, fieldId }">
            <input
              :id="fieldId"
              data-testid="home-widget-title"
              type="text"
              :class="controlClass"
              :value="item.title || ''"
              :placeholder="label"
              :maxlength="60"
              @change="emit('rename', $event.target.value)"
            />
          </template>
        </RaevoField>
        <div class="grid gap-1">
          <span class="text-xs text-n-slate-11">{{
            t('HOME.LAYOUT.MOVE')
          }}</span>
          <div class="flex gap-1">
            <button
              v-for="move in MOVES"
              :key="move.key"
              type="button"
              :data-testid="`home-widget-move-${move.key.toLowerCase()}`"
              class="inline-flex size-8 items-center justify-center rounded-lg border border-solid border-n-weak text-n-slate-11 hover:bg-n-alpha-2 focus:outline-none focus-visible:ring-2 focus-visible:ring-n-brand/40"
              :aria-label="t(`HOME.LAYOUT.MOVE_${move.key}`)"
              :title="t(`HOME.LAYOUT.MOVE_${move.key}`)"
              @click="emit('nudge', move.change)"
            >
              <i :class="move.icon" class="size-4" aria-hidden="true" />
            </button>
          </div>
        </div>
        <div class="grid gap-1">
          <span class="text-xs text-n-slate-11">{{
            t('HOME.LAYOUT.SIZE')
          }}</span>
          <div class="flex gap-1">
            <button
              v-for="size in SIZES"
              :key="size.key"
              type="button"
              :data-testid="`home-widget-size-${size.key.toLowerCase()}`"
              class="inline-flex size-8 items-center justify-center rounded-lg border border-solid border-n-weak text-n-slate-11 hover:bg-n-alpha-2 focus:outline-none focus-visible:ring-2 focus-visible:ring-n-brand/40"
              :aria-label="t(`HOME.LAYOUT.SIZE_${size.key}`)"
              :title="t(`HOME.LAYOUT.SIZE_${size.key}`)"
              @click="emit('nudge', size.change)"
            >
              <i :class="size.icon" class="size-4" aria-hidden="true" />
            </button>
          </div>
        </div>
        <span class="text-xs tabular-nums text-n-slate-11">
          {{ t('HOME.LAYOUT.CURRENT_SIZE', { w: item.w, h: item.h }) }}
        </span>
      </div>

      <!--
        O canto é só para o rato: quem usa teclado tem Shift + setas, e quem usa
        um só ponteiro tem os botões do painel. Por isso não entra no Tab.
      -->
      <span
        data-testid="home-widget-resize"
        class="absolute bottom-1 end-1 size-4 cursor-nwse-resize rounded-sm border-b-2 border-e-2 border-solid border-n-slate-9"
        aria-hidden="true"
        @pointerdown.stop.prevent="emit('dragStart', $event, 'resize')"
      />
    </template>
  </div>
</template>
