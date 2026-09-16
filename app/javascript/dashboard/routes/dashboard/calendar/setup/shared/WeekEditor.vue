<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import SetupButton from './SetupButton.vue';
import SetupSwitch from './SetupSwitch.vue';
import TimeField from './TimeField.vue';

// A semana de um horário: um dia por linha, com interruptor, vários intervalos,
// «+ intervalo» e «Copiar para…». Tudo por botão e campo — nada de arrastar.
const props = defineProps({
  modelValue: { type: Array, default: () => [] },
  disabled: { type: Boolean, default: false },
});

const emit = defineEmits(['update:modelValue']);
const { t } = useI18n();

// Segunda primeiro, como a clínica pensa a semana.
const WEEKDAYS = [1, 2, 3, 4, 5, 6, 0];
const WEEKDAY_KEYS = [
  'SUNDAY',
  'MONDAY',
  'TUESDAY',
  'WEDNESDAY',
  'THURSDAY',
  'FRIDAY',
  'SATURDAY',
];
const DEFAULT_RANGE = { from: '08:00', to: '12:00' };

const copyingFrom = ref(null);
const copyTargets = ref([]);

const rangesFor = weekday =>
  props.modelValue.find(day => day.weekday === weekday)?.ranges || [];

const days = computed(() =>
  WEEKDAYS.map(weekday => ({
    weekday,
    label: t(`CALENDAR_SETUP.WEEKDAYS.${WEEKDAY_KEYS[weekday]}`),
    ranges: rangesFor(weekday),
  }))
);

const commit = (weekday, ranges) => {
  const others = props.modelValue.filter(day => day.weekday !== weekday);
  const next = ranges.length ? [...others, { weekday, ranges }] : others;
  emit(
    'update:modelValue',
    next.sort(
      (a, b) => WEEKDAYS.indexOf(a.weekday) - WEEKDAYS.indexOf(b.weekday)
    )
  );
};

const toggleDay = (weekday, open) =>
  commit(weekday, open ? [{ ...DEFAULT_RANGE }] : []);

const addRange = weekday => {
  const ranges = rangesFor(weekday);
  const last = ranges[ranges.length - 1];
  const next = last ? { from: last.to, to: last.to } : { ...DEFAULT_RANGE };
  commit(weekday, [...ranges, next]);
};

const updateRange = (weekday, index, field, value) =>
  commit(
    weekday,
    rangesFor(weekday).map((range, position) =>
      position === index ? { ...range, [field]: value } : range
    )
  );

const removeRange = (weekday, index) =>
  commit(
    weekday,
    rangesFor(weekday).filter((_, position) => position !== index)
  );

const openCopy = weekday => {
  copyingFrom.value = copyingFrom.value === weekday ? null : weekday;
  copyTargets.value = [];
};

const applyCopy = () => {
  const source = rangesFor(copyingFrom.value).map(range => ({ ...range }));
  const untouched = props.modelValue.filter(
    day => !copyTargets.value.includes(day.weekday)
  );
  const copied = copyTargets.value.map(weekday => ({
    weekday,
    ranges: source.map(range => ({ ...range })),
  }));
  emit(
    'update:modelValue',
    [...untouched, ...copied].sort(
      (a, b) => WEEKDAYS.indexOf(a.weekday) - WEEKDAYS.indexOf(b.weekday)
    )
  );
  copyingFrom.value = null;
};

const toggleTarget = weekday => {
  copyTargets.value = copyTargets.value.includes(weekday)
    ? copyTargets.value.filter(value => value !== weekday)
    : [...copyTargets.value, weekday];
};
</script>

<template>
  <div class="grid gap-2" data-testid="calendar-week-editor">
    <div
      v-for="day in days"
      :key="day.weekday"
      class="grid items-center gap-2.5 md:grid-cols-[110px_minmax(0,1fr)_auto]"
      :data-testid="`calendar-week-day-${day.weekday}`"
    >
      <span class="flex items-center gap-2 text-ui text-n-slate-12">
        <SetupSwitch
          :model-value="day.ranges.length > 0"
          :label="day.label"
          :disabled="disabled"
          @update:model-value="open => toggleDay(day.weekday, open)"
        />
        {{ day.label }}
      </span>

      <span
        v-if="day.ranges.length"
        class="flex flex-wrap items-center gap-1.5"
      >
        <span
          v-for="(range, index) in day.ranges"
          :key="index"
          class="flex items-center gap-1 rounded-lg border border-solid border-n-strong bg-n-solid-1 py-1 pl-2 pr-1 text-xs tabular-nums text-n-slate-12"
        >
          <TimeField
            :model-value="range.from"
            :label="
              t('CALENDAR_SETUP.SCHEDULES.RANGE_FROM', { day: day.label })
            "
            :disabled="disabled"
            @update:model-value="
              value => updateRange(day.weekday, index, 'from', value)
            "
          />
          <span aria-hidden="true">—</span>
          <TimeField
            :model-value="range.to"
            :label="t('CALENDAR_SETUP.SCHEDULES.RANGE_TO', { day: day.label })"
            :disabled="disabled"
            @update:model-value="
              value => updateRange(day.weekday, index, 'to', value)
            "
          />
          <button
            type="button"
            class="flex size-5 items-center justify-center rounded-full p-0 text-n-slate-10 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus-visible:ring-2 focus-visible:ring-n-brand/40"
            :aria-label="t('CALENDAR_SETUP.SCHEDULES.REMOVE_RANGE')"
            :title="t('CALENDAR_SETUP.SCHEDULES.REMOVE_RANGE')"
            :disabled="disabled"
            @click="removeRange(day.weekday, index)"
          >
            <i class="i-lucide-x size-3" aria-hidden="true" />
          </button>
        </span>
        <SetupButton
          variant="dashed"
          :label="t('CALENDAR_SETUP.SCHEDULES.ADD_RANGE')"
          :disabled="disabled"
          @click="addRange(day.weekday)"
        />
      </span>
      <span v-else class="text-xs text-n-slate-10">
        {{ t('CALENDAR_SETUP.SCHEDULES.CLOSED') }}
      </span>

      <span v-if="day.ranges.length" class="relative">
        <SetupButton
          size="sm"
          :label="t('CALENDAR_SETUP.SCHEDULES.COPY_TO')"
          :disabled="disabled"
          :aria-expanded="copyingFrom === day.weekday ? 'true' : 'false'"
          @click="openCopy(day.weekday)"
        />
        <div
          v-if="copyingFrom === day.weekday"
          class="absolute right-0 top-full z-20 mt-1 grid w-48 gap-1 rounded-xl border border-solid border-n-weak bg-n-solid-1 p-2 shadow-lg"
          :data-testid="`calendar-week-copy-${day.weekday}`"
        >
          <label
            v-for="target in days.filter(item => item.weekday !== day.weekday)"
            :key="target.weekday"
            class="flex items-center gap-2 rounded-md px-1.5 py-1 text-ui text-n-slate-12 hover:bg-n-alpha-1"
          >
            <input
              type="checkbox"
              class="mb-0"
              :checked="copyTargets.includes(target.weekday)"
              @change="toggleTarget(target.weekday)"
            />
            {{ target.label }}
          </label>
          <SetupButton
            variant="primary"
            size="sm"
            :label="t('CALENDAR_SETUP.SCHEDULES.COPY_APPLY')"
            :disabled="!copyTargets.length"
            @click="applyCopy"
          />
        </div>
      </span>
      <span v-else />
    </div>
  </div>
</template>
