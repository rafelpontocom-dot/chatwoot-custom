<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import CalendarAPI from 'dashboard/api/calendar';
import RaevoField from 'dashboard/components-next/raevo/RaevoField.vue';
import ExceptionsEditor from './shared/ExceptionsEditor.vue';
import SetupButton from './shared/SetupButton.vue';
import SetupGroup from './shared/SetupGroup.vue';
import SetupHead from './shared/SetupHead.vue';
import SetupPill from './shared/SetupPill.vue';
import SetupRow from './shared/SetupRow.vue';
import SetupSwitch from './shared/SetupSwitch.vue';
import WeekEditor from './shared/WeekEditor.vue';
import {
  apiErrorMessage,
  timezoneLabel,
  timezoneOptions,
  weekSummary,
} from './setupHelpers';
import { useCalendarSetup } from './useCalendarSetup';

const { t } = useI18n();
const { schedules, resources, loadSchedules, loadResources } =
  useCalendarSetup();

const selectedId = ref(null);
const draft = ref(null);
const isEditingDetails = ref(false);
const isSaving = ref(false);
const error = ref('');
const savedAt = ref(null);
const applyOpen = ref(false);
const applyIds = ref([]);
const applyOutside = ref(null);

const SHORT_DAYS = computed(() =>
  ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'].map(key =>
    t(`CALENDAR_SETUP.WEEKDAYS_SHORT.${key}`)
  )
);

const inUseCount = computed(
  () => schedules.value.filter(schedule => schedule.resources_count > 0).length
);

const summaryFor = schedule => {
  const week = weekSummary(schedule.weekly, SHORT_DAYS.value);
  const usage = t(
    'CALENDAR_SETUP.SCHEDULES.USED_BY',
    schedule.resources_count,
    {
      count: schedule.resources_count,
    }
  );
  return week ? `${week} · ${usage}` : usage;
};

const pillFor = schedule => {
  if (schedule.default)
    return { tone: 'on', label: t('CALENDAR_SETUP.SCHEDULES.DEFAULT') };
  if (schedule.resources_count > 0)
    return { tone: 'neutral', label: t('CALENDAR_SETUP.SCHEDULES.IN_USE') };
  return { tone: 'warn', label: t('CALENDAR_SETUP.SCHEDULES.UNUSED') };
};

const toDraft = schedule => ({
  id: schedule?.id || null,
  name: schedule?.name || '',
  timezone: schedule?.timezone || 'America/Sao_Paulo',
  default: schedule?.default || false,
  weekly: JSON.parse(JSON.stringify(schedule?.weekly || [])),
  overrides: JSON.parse(JSON.stringify(schedule?.overrides || [])),
});

const selected = computed(() =>
  schedules.value.find(schedule => schedule.id === selectedId.value)
);

const isDirty = computed(
  () =>
    draft.value &&
    JSON.stringify(draft.value) !== JSON.stringify(toDraft(selected.value))
);

const select = schedule => {
  selectedId.value = schedule.id;
  draft.value = toDraft(schedule);
  isEditingDetails.value = false;
  applyOpen.value = false;
  error.value = '';
};

const startNew = () => {
  selectedId.value = null;
  draft.value = toDraft(null);
  draft.value.weekly = [1, 2, 3, 4, 5].map(weekday => ({
    weekday,
    ranges: [{ from: '08:00', to: '18:00' }],
  }));
  isEditingDetails.value = true;
  applyOpen.value = false;
};

const save = async () => {
  if (!draft.value.name.trim()) {
    isEditingDetails.value = true;
    error.value = t('CALENDAR_SETUP.SCHEDULES.NAME_REQUIRED');
    return;
  }
  isSaving.value = true;
  error.value = '';
  const details = {
    schedule: {
      name: draft.value.name.trim(),
      timezone: draft.value.timezone,
      default_schedule: draft.value.default,
    },
  };
  const sheet = {
    weekly: draft.value.weekly,
    overrides: draft.value.overrides,
  };
  try {
    let id = draft.value.id;
    if (id) {
      await CalendarAPI.updateSchedule(id, details);
      await CalendarAPI.updateScheduleRules(id, sheet);
    } else {
      const { data } = await CalendarAPI.createSchedule({
        ...details,
        ...sheet,
      });
      id = data.id;
    }
    await loadSchedules();
    select(schedules.value.find(schedule => schedule.id === id));
    savedAt.value = Date.now();
  } catch (saveError) {
    error.value = apiErrorMessage(
      saveError,
      t('CALENDAR_SETUP.COMMON.SAVE_ERROR')
    );
  } finally {
    isSaving.value = false;
  }
};

const remove = async () => {
  isSaving.value = true;
  try {
    await CalendarAPI.deleteSchedule(selectedId.value);
    selectedId.value = null;
    draft.value = null;
    await loadSchedules();
  } catch (removeError) {
    error.value = apiErrorMessage(
      removeError,
      t('CALENDAR_SETUP.COMMON.SAVE_ERROR')
    );
  } finally {
    isSaving.value = false;
  }
};

const openApply = () => {
  applyOpen.value = !applyOpen.value;
  applyIds.value = (selected.value?.resources || []).map(
    resource => resource.id
  );
  applyOutside.value = null;
};

watch(applyIds, async ids => {
  applyOutside.value = null;
  if (!applyOpen.value || !ids.length) return;
  const { data } = await CalendarAPI.applySchedule(selectedId.value, {
    resource_ids: ids,
    dry_run: true,
  });
  applyOutside.value = data.appointments_outside;
});

const toggleApply = id => {
  applyIds.value = applyIds.value.includes(id)
    ? applyIds.value.filter(value => value !== id)
    : [...applyIds.value, id];
};

const apply = async () => {
  isSaving.value = true;
  try {
    await CalendarAPI.applySchedule(selectedId.value, {
      resource_ids: applyIds.value,
    });
    await Promise.all([loadSchedules(), loadResources()]);
    select(selected.value);
  } catch (applyError) {
    error.value = apiErrorMessage(
      applyError,
      t('CALENDAR_SETUP.COMMON.SAVE_ERROR')
    );
  } finally {
    isSaving.value = false;
  }
};

onMounted(async () => {
  if (!schedules.value.length) await loadSchedules();
  if (!resources.value.length) await loadResources();
  const first =
    schedules.value.find(schedule => schedule.resources_count > 0) ||
    schedules.value[0];
  if (first && !draft.value) select(first);
});
</script>

<template>
  <section
    class="grid content-start gap-4 px-5 py-[18px]"
    data-testid="calendar-setup-schedules"
  >
    <SetupHead
      :title="t('CALENDAR_SETUP.SCHEDULES.TITLE')"
      :description="t('CALENDAR_SETUP.SCHEDULES.DESCRIPTION')"
    >
      <SetupButton
        variant="primary"
        :label="t('CALENDAR_SETUP.SCHEDULES.NEW')"
        data-testid="calendar-schedule-new"
        @click="startNew"
      />
    </SetupHead>

    <SetupGroup
      :title="t('CALENDAR_SETUP.SCHEDULES.LIST_GROUP')"
      :hint="t('CALENDAR_SETUP.SCHEDULES.IN_USE_COUNT', { count: inUseCount })"
      flush
    >
      <p v-if="!schedules.length" class="mb-0 py-2.5 text-ui text-n-slate-10">
        {{ t('CALENDAR_SETUP.SCHEDULES.EMPTY') }}
      </p>
      <SetupRow
        v-for="schedule in schedules"
        :key="schedule.id"
        clickable
        :title="schedule.name"
        :hint="summaryFor(schedule)"
        :data-testid="`calendar-schedule-row-${schedule.id}`"
        @select="select(schedule)"
      >
        <i
          v-if="schedule.id === selectedId"
          class="i-lucide-pencil size-3.5 text-n-brand"
          :aria-label="t('CALENDAR_SETUP.COMMON.EDITING')"
        />
        <SetupPill v-bind="pillFor(schedule)" />
      </SetupRow>
    </SetupGroup>

    <template v-if="draft">
      <SetupGroup
        :title="draft.name || t('CALENDAR_SETUP.SCHEDULES.NEW_TITLE')"
        data-testid="calendar-schedule-editor"
      >
        <template #aside>
          <span class="flex items-center gap-2">
            <small class="text-xs text-n-slate-10">
              {{
                t('CALENDAR_SETUP.SCHEDULES.TIMEZONE', {
                  zone: timezoneLabel(draft.timezone),
                })
              }}
            </small>
            <SetupButton
              size="sm"
              :label="
                isEditingDetails
                  ? t('CALENDAR_SETUP.COMMON.CLOSE')
                  : t('CALENDAR_SETUP.SCHEDULES.EDIT_DETAILS')
              "
              @click="isEditingDetails = !isEditingDetails"
            />
          </span>
        </template>

        <div
          v-if="isEditingDetails"
          class="grid gap-3 border-b border-solid border-n-weak pb-3 md:grid-cols-[minmax(0,1fr)_minmax(0,1fr)_auto] md:items-end"
        >
          <RaevoField compact :label="t('CALENDAR_SETUP.SCHEDULES.NAME')">
            <template #default="{ controlClass, fieldId }">
              <input
                :id="fieldId"
                v-model="draft.name"
                type="text"
                :class="controlClass"
                :placeholder="t('CALENDAR_SETUP.SCHEDULES.NAME_PLACEHOLDER')"
                data-testid="calendar-schedule-name"
              />
            </template>
          </RaevoField>
          <RaevoField
            compact
            variant="select"
            :label="t('CALENDAR_SETUP.SCHEDULES.TIMEZONE_LABEL')"
          >
            <template #default="{ controlClass, fieldId }">
              <select
                :id="fieldId"
                v-model="draft.timezone"
                :class="controlClass"
              >
                <option
                  v-for="option in timezoneOptions(draft.timezone)"
                  :key="option.value"
                  :value="option.value"
                >
                  {{ option.label }}
                </option>
              </select>
            </template>
          </RaevoField>
          <label class="flex h-9 items-center gap-2 text-ui text-n-slate-12">
            <SetupSwitch
              v-model="draft.default"
              :label="t('CALENDAR_SETUP.SCHEDULES.MAKE_DEFAULT')"
            />
            {{ t('CALENDAR_SETUP.SCHEDULES.MAKE_DEFAULT') }}
          </label>
        </div>

        <WeekEditor v-model="draft.weekly" :disabled="isSaving" />
      </SetupGroup>

      <SetupGroup
        :title="t('CALENDAR_SETUP.SCHEDULES.EXCEPTIONS')"
        :hint="t('CALENDAR_SETUP.SCHEDULES.EXCEPTIONS_HINT')"
        flush
      >
        <ExceptionsEditor v-model="draft.overrides" :disabled="isSaving" />
      </SetupGroup>

      <SetupGroup
        v-if="applyOpen"
        :title="t('CALENDAR_SETUP.SCHEDULES.APPLY')"
        :hint="t('CALENDAR_SETUP.SCHEDULES.APPLY_HINT')"
        tone="muted"
        data-testid="calendar-schedule-apply"
      >
        <div class="flex flex-wrap gap-x-4 gap-y-2">
          <label
            v-for="resource in resources.filter(item => item.active)"
            :key="resource.id"
            class="flex items-center gap-2 text-ui text-n-slate-12"
          >
            <input
              type="checkbox"
              class="mb-0"
              :checked="applyIds.includes(resource.id)"
              @change="toggleApply(resource.id)"
            />
            {{ resource.name }}
          </label>
        </div>
        <p
          v-if="applyOutside"
          class="mb-0 flex items-center gap-1.5 text-ui text-n-amber-11"
          role="status"
          data-testid="calendar-schedule-apply-warning"
        >
          <i class="i-lucide-triangle-alert size-4" aria-hidden="true" />
          {{
            t('CALENDAR_SETUP.SCHEDULES.APPLY_WARNING', applyOutside, {
              count: applyOutside,
            })
          }}
        </p>
        <div class="flex justify-end">
          <SetupButton
            variant="primary"
            size="sm"
            :label="t('CALENDAR_SETUP.SCHEDULES.APPLY_CONFIRM')"
            :disabled="!applyIds.length || isDirty"
            :loading="isSaving"
            data-testid="calendar-schedule-apply-confirm"
            @click="apply"
          />
        </div>
        <p v-if="isDirty" class="mb-0 text-xs text-n-slate-10">
          {{ t('CALENDAR_SETUP.SCHEDULES.SAVE_BEFORE_APPLY') }}
        </p>
      </SetupGroup>

      <p v-if="error" class="mb-0 text-ui text-n-ruby-11" role="alert">
        {{ error }}
      </p>

      <div class="flex flex-wrap items-center justify-between gap-2">
        <span class="flex flex-wrap items-center gap-2">
          <SetupButton
            v-if="draft.id"
            :label="t('CALENDAR_SETUP.SCHEDULES.APPLY')"
            data-testid="calendar-schedule-apply-open"
            @click="openApply"
          />
          <SetupButton
            v-if="draft.id"
            :label="t('CALENDAR_SETUP.SCHEDULES.DELETE')"
            :disabled="selected?.resources_count > 0 || isSaving"
            :title="
              selected?.resources_count > 0
                ? t('CALENDAR_SETUP.SCHEDULES.DELETE_IN_USE', {
                    count: selected.resources_count,
                  })
                : ''
            "
            @click="remove"
          />
          <small
            v-if="selected?.resources_count > 0"
            class="text-xs text-n-slate-10"
          >
            {{
              t('CALENDAR_SETUP.SCHEDULES.DELETE_IN_USE', {
                count: selected.resources_count,
              })
            }}
          </small>
        </span>
        <span class="flex items-center gap-2">
          <small
            v-if="savedAt && !isDirty"
            class="flex items-center gap-1 text-xs text-n-teal-11"
            role="status"
          >
            <i class="i-lucide-check size-3.5" aria-hidden="true" />
            {{ t('CALENDAR_SETUP.COMMON.SAVED') }}
          </small>
          <SetupButton
            variant="primary"
            :label="t('CALENDAR_SETUP.SCHEDULES.SAVE')"
            :disabled="draft.id && !isDirty"
            :loading="isSaving"
            data-testid="calendar-schedule-save"
            @click="save"
          />
        </span>
      </div>
    </template>
  </section>
</template>
