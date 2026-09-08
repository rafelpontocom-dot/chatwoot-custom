<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import RaevoAiAPI from 'dashboard/api/raevoAi';
import RaevoField from 'dashboard/components-next/raevo/RaevoField.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const { t } = useI18n();
const dayOrder = [1, 2, 3, 4, 5, 6, 0];
const revision = ref(null);
const enabled = ref(false);
const timezone = ref('America/Sao_Paulo');
const days = ref([]);
const isLoading = ref(true);
const isSaving = ref(false);
const error = ref(null);
const saved = ref(false);

const timezoneSuggestions = [
  'America/Sao_Paulo',
  'America/Manaus',
  'America/Cuiaba',
  'America/Rio_Branco',
  'Europe/Lisbon',
  'Europe/London',
  'America/New_York',
  'UTC',
];

const emptyDays = () =>
  dayOrder.map(day => ({ day, enabled: false, periods: [] }));

const dayLabels = computed(() => ({
  0: t('RAEVO_AI.SERVICE_HOURS.DAYS.0'),
  1: t('RAEVO_AI.SERVICE_HOURS.DAYS.1'),
  2: t('RAEVO_AI.SERVICE_HOURS.DAYS.2'),
  3: t('RAEVO_AI.SERVICE_HOURS.DAYS.3'),
  4: t('RAEVO_AI.SERVICE_HOURS.DAYS.4'),
  5: t('RAEVO_AI.SERVICE_HOURS.DAYS.5'),
  6: t('RAEVO_AI.SERVICE_HOURS.DAYS.6'),
}));

const dayLabel = day => dayLabels.value[day];

const errorMessage = computed(() => {
  if (error.value === 'conflict') {
    return t('RAEVO_AI.SERVICE_HOURS.CONFLICT');
  }
  if (error.value === 'invalid') {
    return t('RAEVO_AI.SERVICE_HOURS.INVALID');
  }
  return t('RAEVO_AI.SERVICE_HOURS.ERROR');
});

const normalizeConfig = config => {
  const normalizedDays = emptyDays();
  const windows = Array.isArray(config?.windows) ? config.windows : [];
  windows.forEach(window => {
    const windowDays = Array.isArray(window?.days) ? window.days : [];
    windowDays.forEach(day => {
      const target = normalizedDays.find(item => item.day === Number(day));
      if (!target || !window?.start || !window?.end) return;
      target.enabled = true;
      target.periods.push({ start: window.start, end: window.end });
    });
  });
  normalizedDays.forEach(day =>
    day.periods.sort((left, right) => left.start.localeCompare(right.start))
  );
  days.value = normalizedDays;
  enabled.value = config?.enabled === true;
  timezone.value = config?.timezone || 'America/Sao_Paulo';
  revision.value = Number.isInteger(config?.revision) ? config.revision : null;
};

const load = async () => {
  isLoading.value = true;
  error.value = null;
  try {
    const { data } = await RaevoAiAPI.getServiceHours();
    normalizeConfig(data?.config);
  } catch {
    error.value = 'unavailable';
  } finally {
    isLoading.value = false;
  }
};

const seedDefaultWeekdays = () => {
  if (!enabled.value || days.value.some(day => day.periods.length)) return;
  days.value.forEach(day => {
    if (day.day >= 1 && day.day <= 5) {
      day.enabled = true;
      day.periods = [{ start: '08:00', end: '18:00' }];
    }
  });
};

const toggleDay = day => {
  if (day.enabled && day.periods.length === 0) {
    day.periods.push({ start: '08:00', end: '18:00' });
  }
};

const addPeriod = day => {
  day.enabled = true;
  day.periods.push({ start: '08:00', end: '18:00' });
};

const removePeriod = (day, index) => {
  day.periods.splice(index, 1);
  day.enabled = day.periods.length > 0;
};

const activePeriods = computed(() =>
  days.value.flatMap(day =>
    day.enabled ? day.periods.map(period => ({ day: day.day, ...period })) : []
  )
);

const validSchedule = computed(() => {
  if (!enabled.value) return true;
  if (!activePeriods.value.length || !timezone.value.trim()) return false;

  return days.value.every(day => {
    if (!day.enabled) return true;
    const ordered = [...day.periods].sort((left, right) =>
      left.start.localeCompare(right.start)
    );
    return ordered.every(
      (period, index) =>
        /^\d{2}:\d{2}$/.test(period.start) &&
        /^\d{2}:\d{2}$/.test(period.end) &&
        period.start < period.end &&
        (index === 0 || ordered[index - 1].end <= period.start)
    );
  });
});

const compactWindows = () => {
  if (!enabled.value) return [];
  const grouped = new Map();
  activePeriods.value.forEach(period => {
    const key = [period.start, period.end].join('|');
    const current = grouped.get(key) || {
      days: [],
      start: period.start,
      end: period.end,
    };
    current.days.push(period.day);
    grouped.set(key, current);
  });
  return [...grouped.values()]
    .map(window => ({ ...window, days: window.days.sort((a, b) => a - b) }))
    .sort(
      (left, right) =>
        left.start.localeCompare(right.start) || left.days[0] - right.days[0]
    );
};

const save = async () => {
  if (!validSchedule.value) {
    error.value = 'invalid';
    return;
  }
  isSaving.value = true;
  error.value = null;
  saved.value = false;
  try {
    const { data } = await RaevoAiAPI.saveServiceHours({
      expected_revision: revision.value,
      config: {
        enabled: enabled.value,
        timezone: timezone.value.trim(),
        windows: compactWindows(),
      },
    });
    normalizeConfig(data?.config);
    saved.value = true;
  } catch (requestError) {
    error.value =
      requestError?.response?.status === 409 ? 'conflict' : 'unavailable';
  } finally {
    isSaving.value = false;
  }
};

onMounted(load);
</script>

<template>
  <section
    data-testid="ai-service-hours"
    class="rounded-xl border border-n-weak bg-n-solid-1 p-4 lg:p-5"
  >
    <div class="max-w-3xl">
      <p class="text-micro font-semibold uppercase text-n-slate-10">
        {{ t('RAEVO_AI.SERVICE_HOURS.EYEBROW') }}
      </p>
      <h2 class="mt-1 text-base font-semibold text-n-slate-12">
        {{ t('RAEVO_AI.SERVICE_HOURS.TITLE') }}
      </h2>
      <p class="mt-1 text-sm leading-6 text-n-slate-11">
        {{ t('RAEVO_AI.SERVICE_HOURS.DESCRIPTION') }}
      </p>
    </div>

    <p v-if="isLoading" class="mt-4 text-sm text-n-slate-11" role="status">
      {{ t('RAEVO_AI.SERVICE_HOURS.LOADING') }}
    </p>

    <div v-else class="mt-4 grid max-w-3xl gap-4">
      <label class="flex items-start gap-3 text-sm text-n-slate-12">
        <input
          v-model="enabled"
          data-testid="ai-service-hours-enabled"
          type="checkbox"
          class="mt-0.5 size-4 rounded border-n-strong text-n-brand focus:ring-n-brand"
          :disabled="isSaving"
          @change="seedDefaultWeekdays"
        />
        <span>
          <span class="block font-medium">
            {{ t('RAEVO_AI.SERVICE_HOURS.RESTRICT') }}
          </span>
          <span class="mt-0.5 block text-n-slate-11">
            {{ t('RAEVO_AI.SERVICE_HOURS.RESTRICT_HINT') }}
          </span>
        </span>
      </label>

      <RaevoField
        :label="t('RAEVO_AI.SERVICE_HOURS.TIMEZONE')"
        :hint="t('RAEVO_AI.SERVICE_HOURS.TIMEZONE_HINT')"
      >
        <template #default="{ controlClass, fieldId, describedBy }">
          <input
            :id="fieldId"
            v-model="timezone"
            list="raevo-ai-timezones"
            :class="controlClass"
            :aria-describedby="describedBy"
            :disabled="isSaving"
            autocomplete="off"
          />
          <datalist id="raevo-ai-timezones">
            <option
              v-for="item in timezoneSuggestions"
              :key="item"
              :value="item"
            />
          </datalist>
        </template>
      </RaevoField>

      <div v-if="enabled" class="grid gap-2">
        <article
          v-for="day in days"
          :key="day.day"
          data-testid="ai-service-hours-day"
          class="rounded-xl border border-n-weak bg-n-background p-3"
        >
          <div class="flex flex-wrap items-center justify-between gap-3">
            <label
              class="flex items-center gap-2 text-sm font-medium text-n-slate-12"
            >
              <input
                v-model="day.enabled"
                type="checkbox"
                class="size-4 rounded border-n-strong text-n-brand focus:ring-n-brand"
                :disabled="isSaving"
                @change="toggleDay(day)"
              />
              {{ dayLabel(day.day) }}
            </label>
            <button
              v-if="day.enabled"
              type="button"
              class="rounded-full px-3 py-1.5 text-xs font-medium text-n-brand hover:bg-n-alpha-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
              :disabled="isSaving || day.periods.length >= 4"
              @click="addPeriod(day)"
            >
              {{ t('RAEVO_AI.SERVICE_HOURS.ADD_PERIOD') }}
            </button>
          </div>

          <div v-if="day.enabled" class="mt-3 grid gap-2">
            <div
              v-for="(period, index) in day.periods"
              :key="index"
              class="grid grid-cols-[minmax(0,1fr)_auto_minmax(0,1fr)_auto] items-center gap-2"
            >
              <input
                v-model="period.start"
                type="time"
                class="min-w-0 rounded-lg border border-n-strong bg-n-alpha-1 px-3 py-2 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none"
                :aria-label="
                  t('RAEVO_AI.SERVICE_HOURS.START', { day: dayLabel(day.day) })
                "
                :disabled="isSaving"
              />
              <span class="text-xs text-n-slate-10">
                {{ t('RAEVO_AI.SERVICE_HOURS.TO') }}
              </span>
              <input
                v-model="period.end"
                type="time"
                class="min-w-0 rounded-lg border border-n-strong bg-n-alpha-1 px-3 py-2 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none"
                :aria-label="
                  t('RAEVO_AI.SERVICE_HOURS.END', { day: dayLabel(day.day) })
                "
                :disabled="isSaving"
              />
              <button
                type="button"
                class="grid size-8 place-items-center rounded-full text-n-slate-10 hover:bg-n-alpha-2 hover:text-n-ruby-11 focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
                :aria-label="t('RAEVO_AI.SERVICE_HOURS.REMOVE_PERIOD')"
                :disabled="isSaving"
                @click="removePeriod(day, index)"
              >
                <i class="i-lucide-trash-2 size-4" aria-hidden="true" />
              </button>
            </div>
          </div>
          <p v-else class="mt-2 text-xs text-n-slate-10">
            {{ t('RAEVO_AI.SERVICE_HOURS.CLOSED') }}
          </p>
        </article>
      </div>

      <p v-else class="rounded-lg bg-n-teal-3 px-3 py-2 text-sm text-n-teal-11">
        {{ t('RAEVO_AI.SERVICE_HOURS.ALWAYS_ON') }}
      </p>

      <p v-if="error" class="text-sm text-n-ruby-11" role="alert">
        {{ errorMessage }}
      </p>
      <p v-if="saved" class="text-sm text-n-teal-11" role="status">
        {{ t('RAEVO_AI.SERVICE_HOURS.SAVED') }}
      </p>

      <div>
        <NextButton
          type="button"
          data-testid="ai-service-hours-save"
          :label="t('RAEVO_AI.SERVICE_HOURS.SAVE')"
          :is-loading="isSaving"
          :disabled="isSaving || !validSchedule"
          @click="save"
        />
      </div>
    </div>
  </section>
</template>
