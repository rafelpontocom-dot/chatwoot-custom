<script setup>
import { computed, nextTick, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { isoDate } from '../bookingApi';

// Calendário do mês: dias com vaga em destaque, os outros apagados mas à vista.
// Setas do teclado andam entre dias.
const props = defineProps({
  month: { type: Date, required: true },
  availableDays: { type: Array, default: () => [] },
  selectedDay: { type: String, default: '' },
  loading: { type: Boolean, default: false },
  canGoBack: { type: Boolean, default: true },
});

const emit = defineEmits(['select', 'previous', 'next']);
const { t, locale } = useI18n();
const grid = ref(null);

const bcp47 = computed(() => locale.value.replace('_', '-'));

const title = computed(() =>
  new Intl.DateTimeFormat(bcp47.value, { month: 'long', year: 'numeric' })
    .format(props.month)
    .replace(' de ', ' ')
);

// Segunda primeiro: S T Q Q S S D.
const weekdayInitials = computed(() => {
  const monday = new Date(2026, 8, 21);
  return Array.from({ length: 7 }, (_, offset) => {
    const day = new Date(monday);
    day.setDate(monday.getDate() + offset);
    return new Intl.DateTimeFormat(bcp47.value, { weekday: 'narrow' })
      .format(day)
      .toUpperCase();
  });
});

const cells = computed(() => {
  const first = new Date(props.month.getFullYear(), props.month.getMonth(), 1);
  const lead = (first.getDay() + 6) % 7;
  const total = new Date(
    props.month.getFullYear(),
    props.month.getMonth() + 1,
    0
  ).getDate();
  const available = new Set(props.availableDays);
  const blanks = Array.from({ length: lead }, (_, index) => ({
    key: `blank-${index}`,
  }));
  const days = Array.from({ length: total }, (_, index) => {
    const date = new Date(first.getFullYear(), first.getMonth(), index + 1);
    const iso = isoDate(date);
    return {
      key: iso,
      iso,
      number: index + 1,
      free: available.has(iso),
      label: new Intl.DateTimeFormat(bcp47.value, {
        weekday: 'long',
        day: 'numeric',
        month: 'long',
      }).format(date),
    };
  });
  return [...blanks, ...days];
});

const move = async (event, offset) => {
  const buttons = [...grid.value.querySelectorAll('button[data-day]')];
  const index = buttons.indexOf(event.target);
  const target = buttons[index + offset];
  if (!target) return;
  event.preventDefault();
  await nextTick();
  target.focus();
};

const dayClass = cell => {
  if (props.selectedDay === cell.iso)
    return 'border-n-brand bg-n-brand font-semibold text-white';
  if (cell.free) {
    return 'border-n-weak bg-n-surface-2 font-semibold text-n-slate-12 hover:border-n-brand hover:text-n-brand';
  }
  return 'cursor-default border-transparent bg-transparent text-n-slate-10';
};

const KEYS = { ArrowLeft: -1, ArrowRight: 1, ArrowUp: -7, ArrowDown: 7 };
const onKeydown = event => {
  if (KEYS[event.key] !== undefined) move(event, KEYS[event.key]);
};
</script>

<template>
  <div class="grid gap-3.5">
    <div class="flex items-center justify-between gap-2">
      <div aria-live="polite">
        <strong class="text-sm font-semibold capitalize text-n-slate-12">
          {{ title }}
        </strong>
      </div>
      <span class="flex gap-1">
        <button
          type="button"
          class="grid size-7 place-items-center rounded-full border border-solid border-n-weak bg-n-solid-1 p-0 text-n-slate-11 outline-none hover:text-n-slate-12 focus-visible:ring-2 focus-visible:ring-n-brand/40 disabled:opacity-40"
          :aria-label="t('PUBLIC_BOOKING.PREVIOUS_MONTH')"
          :disabled="!canGoBack"
          data-testid="public-booking-previous-month"
          @click="emit('previous')"
        >
          <i class="i-lucide-chevron-left size-4" aria-hidden="true" />
        </button>
        <button
          type="button"
          class="grid size-7 place-items-center rounded-full border border-solid border-n-weak bg-n-solid-1 p-0 text-n-slate-11 outline-none hover:text-n-slate-12 focus-visible:ring-2 focus-visible:ring-n-brand/40"
          :aria-label="t('PUBLIC_BOOKING.NEXT_MONTH')"
          data-testid="public-booking-next-month"
          @click="emit('next')"
        >
          <i class="i-lucide-chevron-right size-4" aria-hidden="true" />
        </button>
      </span>
    </div>

    <div
      ref="grid"
      class="grid grid-cols-7 gap-[5px]"
      :aria-busy="loading ? 'true' : 'false'"
      data-testid="public-booking-month"
      @keydown="onKeydown"
    >
      <span
        v-for="(initial, index) in weekdayInitials"
        :key="`weekday-${index}`"
        class="pb-0.5 text-center text-micro text-n-slate-10"
        aria-hidden="true"
      >
        {{ initial }}
      </span>
      <template v-for="cell in cells" :key="cell.key">
        <span v-if="!cell.iso" aria-hidden="true" />
        <button
          v-else
          type="button"
          :data-day="cell.iso"
          class="aspect-square rounded-lg border border-solid p-0 text-ui tabular-nums outline-none transition-colors focus-visible:ring-2 focus-visible:ring-n-brand/40"
          :class="dayClass(cell)"
          :aria-label="cell.label"
          :aria-pressed="selectedDay === cell.iso ? 'true' : 'false'"
          :aria-disabled="cell.free ? undefined : 'true'"
          :tabindex="cell.free || selectedDay === cell.iso ? 0 : -1"
          @click="cell.free && emit('select', cell.iso)"
        >
          {{ cell.number }}
        </button>
      </template>
    </div>
    <p class="mb-0 text-xs text-n-slate-10">
      {{ t('PUBLIC_BOOKING.NO_ROOM_HINT') }}
    </p>
  </div>
</template>
