<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

import { RAEVO_CONTROL_CLASS } from 'dashboard/components-next/raevo/raevoControl';

/**
 * Raevo — horário de trabalho no formato do Google Calendar.
 *
 * Antes: escolher um dia, escrever início, escrever fim, carregar em "Adicionar",
 * e repetir cinco vezes para dizer "de segunda a sexta, das 9 às 18". A semana
 * inteira nunca estava à vista — só a lista do que já tinha sido criado.
 *
 * Agora os sete dias estão sempre visíveis, cada um com as suas horas. A caixa
 * de seleção abre e fecha o dia; o "+" acrescenta um segundo intervalo, que é
 * como se representa a pausa do almoço.
 */
const props = defineProps({
  rules: { type: Array, default: () => [] },
  isSaving: { type: Boolean, default: false },
});

const emit = defineEmits(['create', 'update', 'remove']);
const { t } = useI18n();

const DEFAULT_START = '09:00';
const DEFAULT_END = '18:00';

const WEEKDAY_KEYS = [
  'CALENDAR.SETTINGS.WEEKDAYS.SUNDAY',
  'CALENDAR.SETTINGS.WEEKDAYS.MONDAY',
  'CALENDAR.SETTINGS.WEEKDAYS.TUESDAY',
  'CALENDAR.SETTINGS.WEEKDAYS.WEDNESDAY',
  'CALENDAR.SETTINGS.WEEKDAYS.THURSDAY',
  'CALENDAR.SETTINGS.WEEKDAYS.FRIDAY',
  'CALENDAR.SETTINGS.WEEKDAYS.SATURDAY',
];

// A semana começa à segunda: é assim que a agenda da clínica é lida, e é a
// ordem em que o Google apresenta o horário de trabalho.
const WEEK_ORDER = [1, 2, 3, 4, 5, 6, 0];

const weeklyRules = computed(() =>
  props.rules.filter(rule => rule.kind === 'weekly_window' && rule.active)
);

const week = computed(() =>
  WEEK_ORDER.map(weekday => ({
    weekday,
    label: t(WEEKDAY_KEYS[weekday]),
    intervals: weeklyRules.value
      .filter(rule => rule.weekday === weekday)
      .sort((first, second) =>
        String(first.starts_at_local).localeCompare(
          String(second.starts_at_local)
        )
      ),
  }))
);

/** Ligar um dia dá-lhe o horário comum; desligar apaga os intervalos todos. */
const toggleDay = day => {
  if (day.intervals.length) {
    day.intervals.forEach(rule => emit('remove', rule));
    return;
  }
  emit('create', {
    weekday: day.weekday,
    startsAtLocal: DEFAULT_START,
    endsAtLocal: DEFAULT_END,
  });
};

/** Uma hora depois do fim do último período — nunca um intervalo de duração
 * zero, que o servidor recusa por o fim não ser posterior ao início. */
const umaHoraDepois = hora => {
  const [h, m] = String(hora).split(':').map(Number);
  if (Number.isNaN(h)) return DEFAULT_END;
  if (h >= 22) return '23:59';
  return `${String(h + 1).padStart(2, '0')}:${String(m || 0).padStart(2, '0')}`;
};

const addInterval = day => {
  const ultimo = day.intervals[day.intervals.length - 1];
  const inicio = ultimo?.ends_at_local || DEFAULT_START;
  emit('create', {
    weekday: day.weekday,
    startsAtLocal: inicio,
    endsAtLocal: umaHoraDepois(inicio),
  });
};

const changeInterval = (rule, field, value) => {
  if (!value || value === rule[field]) return;
  emit('update', { rule, changes: { [field]: value } });
};
</script>

<template>
  <div class="grid gap-1" data-testid="calendar-working-hours">
    <div
      v-for="day in week"
      :key="day.weekday"
      class="flex min-h-10 items-start gap-3 py-1"
      :data-testid="`working-day-${day.weekday}`"
    >
      <label class="flex w-36 shrink-0 items-center gap-2 pt-2 text-sm">
        <input
          type="checkbox"
          class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
          :checked="day.intervals.length > 0"
          :disabled="isSaving"
          :data-testid="`working-day-toggle-${day.weekday}`"
          @change="toggleDay(day)"
        />
        <span class="truncate text-n-slate-12">{{ day.label }}</span>
      </label>

      <p
        v-if="!day.intervals.length"
        class="mb-0 pt-2 text-sm text-n-slate-10"
        :data-testid="`working-day-closed-${day.weekday}`"
      >
        {{ t('CALENDAR.SETTINGS.AVAILABILITY.CLOSED') }}
      </p>

      <div v-else class="grid min-w-0 gap-1">
        <div
          v-for="interval in day.intervals"
          :key="interval.id"
          class="flex items-center gap-2"
        >
          <div class="w-28 shrink-0">
            <input
              type="time"
              :value="interval.starts_at_local"
              :disabled="isSaving"
              :class="RAEVO_CONTROL_CLASS"
              :aria-label="t('CALENDAR.SETTINGS.AVAILABILITY.START')"
              @change="
                changeInterval(interval, 'starts_at_local', $event.target.value)
              "
            />
          </div>
          <span class="text-sm text-n-slate-10" aria-hidden="true">–</span>
          <div class="w-28 shrink-0">
            <input
              type="time"
              :value="interval.ends_at_local"
              :disabled="isSaving"
              :class="RAEVO_CONTROL_CLASS"
              :aria-label="t('CALENDAR.SETTINGS.AVAILABILITY.END')"
              @change="
                changeInterval(interval, 'ends_at_local', $event.target.value)
              "
            />
          </div>
          <button
            type="button"
            class="flex p-0 size-8 shrink-0 items-center justify-center rounded-full text-n-slate-11 outline-none hover:bg-n-alpha-2 focus-visible:ring-2 focus-visible:ring-n-brand"
            :disabled="isSaving"
            :title="t('CALENDAR.SETTINGS.AVAILABILITY.REMOVE')"
            :aria-label="t('CALENDAR.SETTINGS.AVAILABILITY.REMOVE')"
            :data-testid="`working-interval-remove-${interval.id}`"
            @click="emit('remove', interval)"
          >
            <i class="i-lucide-x size-4" aria-hidden="true" />
          </button>
        </div>
      </div>

      <button
        v-if="day.intervals.length"
        type="button"
        class="flex p-0 size-8 shrink-0 items-center justify-center rounded-full text-n-slate-11 outline-none hover:bg-n-alpha-2 focus-visible:ring-2 focus-visible:ring-n-brand"
        :disabled="isSaving"
        :title="t('CALENDAR.SETTINGS.AVAILABILITY.ADD_INTERVAL')"
        :aria-label="t('CALENDAR.SETTINGS.AVAILABILITY.ADD_INTERVAL')"
        :data-testid="`working-day-add-${day.weekday}`"
        @click="addInterval(day)"
      >
        <i class="i-lucide-plus size-4" aria-hidden="true" />
      </button>
    </div>
  </div>
</template>
