<script setup>
import { computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import RaevoField from 'dashboard/components-next/raevo/RaevoField.vue';
import ExceptionsEditor from '../shared/ExceptionsEditor.vue';
import SetupChips from '../shared/SetupChips.vue';
import SetupGroup from '../shared/SetupGroup.vue';
import SetupRow from '../shared/SetupRow.vue';
import WeekEditor from '../shared/WeekEditor.vue';
import { useCalendarSetup } from '../useCalendarSetup';
import { useProcedureDraft } from './procedureDraft';

const { t, locale } = useI18n();
const { draft, preview, loadPreview, isDirty, ownScheduleLoaded } =
  useProcedureDraft();
const { schedules, resources } = useCalendarSetup();

const modeOptions = computed(() =>
  ['resources', 'schedule', 'own'].map(mode => ({
    value: mode,
    label: t(`CALENDAR_SETUP.PROCEDURE.WHEN.MODES.${mode.toUpperCase()}`),
    testid: `calendar-procedure-when-${mode}`,
  }))
);

// Um por tipo: entre profissionais basta um livre («Dr. Bruno ou Dra. Ana»);
// sala e equipamento entram juntos.
const resourceNames = computed(() => {
  const chosen = draft.value.resource_ids
    .map(id => resources.value.find(resource => resource.id === id))
    .filter(Boolean);
  const byType = ['user', 'room', 'equipment', 'generic']
    .map(type =>
      chosen
        .filter(resource => resource.resource_type === type)
        .map(resource => resource.name)
    )
    .filter(names => names.length)
    .map(names => names.join(` ${t('CALENDAR_SETUP.COMMON.OR')} `));
  if (byType.length < 2) return byType.join('');
  return `${byType.slice(0, -1).join(', ')} ${t('CALENDAR_SETUP.COMMON.AND')} ${byType[byType.length - 1]}`;
});

const help = computed(() => {
  const params = {
    procedure: draft.value.name,
    resources: resourceNames.value,
  };
  if (draft.value.when_mode === 'resources' && !resourceNames.value)
    return t('CALENDAR_SETUP.PROCEDURE.WHEN.HELP_RESOURCES_EMPTY');
  return t(
    `CALENDAR_SETUP.PROCEDURE.WHEN.HELP_${draft.value.when_mode.toUpperCase()}`,
    params
  );
});

const formatDay = iso =>
  new Date(`${iso}T12:00:00`).toLocaleDateString(
    locale.value.replace('_', '-'),
    {
      weekday: 'short',
      day: 'numeric',
      month: 'short',
    }
  );

const formatTime = (iso, timezone) =>
  new Date(iso).toLocaleTimeString(locale.value.replace('_', '-'), {
    hour: '2-digit',
    minute: '2-digit',
    timeZone: timezone,
  });

// Cada dia mostra quem atende no primeiro horário; horários com outra equipe
// ficam no mesmo dia, com os nomes à vista quando mudam.
const days = computed(() =>
  (preview.value?.days || []).map(day => ({
    date: day.date,
    title: formatDay(day.date),
    hint: [...new Set(day.slots.map(slot => slot.resources.join(' · ')))].join(
      ' / '
    ),
    times: day.slots.map(slot =>
      formatTime(slot.starts_at, preview.value.timezone)
    ),
  }))
);

watch(
  () => draft.value.when_mode,
  mode => {
    if (mode === 'own') ownScheduleLoaded();
  }
);

onMounted(() => {
  if (draft.value.id) loadPreview();
  if (draft.value.when_mode === 'own') ownScheduleLoaded();
});

const scheduleMissing = computed(
  () => draft.value.when_mode === 'schedule' && !draft.value.schedule_id
);
</script>

<template>
  <SetupGroup
    :title="t('CALENDAR_SETUP.PROCEDURE.WHEN.GROUP')"
    :hint="t('CALENDAR_SETUP.PROCEDURE.WHEN.GROUP_HINT')"
    data-testid="calendar-procedure-tab-when"
  >
    <SetupChips
      v-model="draft.when_mode"
      :label="t('CALENDAR_SETUP.PROCEDURE.WHEN.GROUP')"
      :options="modeOptions"
    />
    <p class="mb-0 text-xs text-n-slate-10">{{ help }}</p>

    <RaevoField
      v-if="draft.when_mode === 'schedule'"
      compact
      variant="select"
      :label="t('CALENDAR_SETUP.PROCEDURE.WHEN.PICK_SCHEDULE')"
      :error="
        scheduleMissing
          ? t('CALENDAR_SETUP.PROCEDURE.WHEN.SCHEDULE_REQUIRED')
          : ''
      "
    >
      <template #default="{ controlClass, fieldId }">
        <select
          :id="fieldId"
          v-model="draft.schedule_id"
          :class="controlClass"
          data-testid="calendar-procedure-schedule"
        >
          <option :value="null" disabled>
            {{ t('CALENDAR_SETUP.PROCEDURE.WHEN.PICK_SCHEDULE') }}
          </option>
          <option
            v-for="schedule in schedules"
            :key="schedule.id"
            :value="schedule.id"
          >
            {{ schedule.name }}
          </option>
        </select>
      </template>
    </RaevoField>

    <div
      v-if="draft.when_mode === 'own'"
      class="grid gap-3 rounded-lg border border-solid border-n-weak bg-n-surface-2 p-3"
      data-testid="calendar-procedure-own-schedule"
    >
      <WeekEditor v-model="draft.own_weekly" />
      <strong class="text-ui font-semibold text-n-slate-12">{{
        t('CALENDAR_SETUP.SCHEDULES.EXCEPTIONS')
      }}</strong>
      <ExceptionsEditor v-model="draft.own_overrides" />
    </div>

    <SetupGroup
      v-if="draft.id"
      :title="t('CALENDAR_SETUP.PROCEDURE.WHEN.PREVIEW_TITLE')"
      :hint="
        isDirty
          ? t('CALENDAR_SETUP.PROCEDURE.WHEN.PREVIEW_SAVED_ONLY')
          : t('CALENDAR_SETUP.PROCEDURE.WHEN.PREVIEW_HINT')
      "
      tone="muted"
      flush
      data-testid="calendar-procedure-preview"
    >
      <p v-if="preview === null" class="mb-0 py-2 text-ui text-n-slate-10">
        {{ t('CALENDAR_SETUP.COMMON.LOADING') }}
      </p>
      <p v-else-if="!days.length" class="mb-0 py-2 text-ui text-n-slate-10">
        {{ t('CALENDAR_SETUP.PROCEDURE.WHEN.PREVIEW_EMPTY') }}
      </p>
      <SetupRow
        v-for="day in days"
        :key="day.date"
        :title="day.title"
        :hint="day.hint"
      >
        <span
          v-for="(time, index) in day.times"
          :key="index"
          class="rounded-full border border-solid border-n-strong bg-n-solid-1 px-[11px] py-[5px] text-xs tabular-nums text-n-slate-11"
        >
          {{ time }}
        </span>
      </SetupRow>
    </SetupGroup>
  </SetupGroup>
</template>
