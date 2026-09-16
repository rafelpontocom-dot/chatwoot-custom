<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import CalendarAPI from 'dashboard/api/calendar';
import RaevoField from 'dashboard/components-next/raevo/RaevoField.vue';
import ExceptionsEditor from './shared/ExceptionsEditor.vue';
import ResourceGoogleConnection from './ResourceGoogleConnection.vue';
import SetupButton from './shared/SetupButton.vue';
import SetupGroup from './shared/SetupGroup.vue';
import SetupHead from './shared/SetupHead.vue';
import SetupPill from './shared/SetupPill.vue';
import SetupRow from './shared/SetupRow.vue';
import WeekEditor from './shared/WeekEditor.vue';
import { apiErrorMessage } from './setupHelpers';
import { useCalendarSetup } from './useCalendarSetup';

const OWN = 'own';
const SLOT_INTERVALS = [5, 10, 15, 20, 30, 60];

const { t } = useI18n();
const store = useStore();
const agents = useMapGetter('agents/getAgents');
const { resources, schedules, loadResources, loadSchedules } =
  useCalendarSetup();

const accountInterval = ref(15);
const feegowProfessionals = ref([]);
const form = ref(null);
const ownHours = ref({ weekly: [], overrides: [] });
const savedOwnHours = ref('');
const isSaving = ref(false);
const error = ref('');
const formGroup = ref(null);

const emptyForm = () => ({
  id: null,
  name: '',
  resourceType: 'user',
  userId: '',
  scheduleId: schedules.value.find(schedule => schedule.default)?.id || OWN,
  slotInterval: '',
  feegowProfessionalId: '',
});

const activeResources = computed(() =>
  resources.value.filter(resource => resource.active)
);
const professionals = computed(() =>
  activeResources.value.filter(resource => resource.resource_type === 'user')
);
const others = computed(() =>
  activeResources.value.filter(resource => resource.resource_type !== 'user')
);

const hintFor = resource => {
  if (resource.missing_hours) return t('CALENDAR_SETUP.RESOURCES.MISSING');
  const line = resource.schedule
    ? t('CALENDAR_SETUP.RESOURCES.SCHEDULE_LINE', {
        name: resource.schedule.name,
      })
    : t('CALENDAR_SETUP.RESOURCES.OWN_HOURS');
  return resource.resource_type === 'user' && resource.slot_interval_minutes
    ? `${line} · ${t('CALENDAR_SETUP.RESOURCES.SPACING', { count: resource.slot_interval_minutes })}`
    : line;
};

const typeLabel = type =>
  t(`CALENDAR_SETUP.RESOURCES.TYPE_PILLS.${type.toUpperCase()}`);

const loadExtras = async () => {
  try {
    const { data } = await CalendarAPI.getBookingPage();
    accountInterval.value = data.slot_interval_minutes || 15;
  } catch {
    accountInterval.value = 15;
  }
  try {
    const { data } = await CalendarAPI.getFeegowConnection();
    if (data?.connected) {
      const professionalsResponse = await CalendarAPI.getFeegowProfessionals();
      feegowProfessionals.value = professionalsResponse.data || [];
    }
  } catch {
    feegowProfessionals.value = [];
  }
};

const loadOwnHours = async id => {
  if (!id) {
    ownHours.value = {
      weekly: [1, 2, 3, 4, 5].map(weekday => ({
        weekday,
        ranges: [{ from: '08:00', to: '18:00' }],
      })),
      overrides: [],
    };
  } else {
    const { data } = await CalendarAPI.getResourceWorkingHours(id);
    ownHours.value = {
      weekly: data.weekly || [],
      overrides: data.overrides || [],
    };
  }
  savedOwnHours.value = JSON.stringify(ownHours.value);
};

const edit = async resource => {
  error.value = '';
  form.value = {
    id: resource.id,
    name: resource.name,
    resourceType: resource.resource_type,
    userId: resource.user_id ? String(resource.user_id) : '',
    scheduleId: resource.schedule?.id || OWN,
    slotInterval: resource.slot_interval_minutes
      ? String(resource.slot_interval_minutes)
      : '',
    feegowProfessionalId: resource.feegow_professional_id
      ? String(resource.feegow_professional_id)
      : '',
  };
  await loadOwnHours(resource.id);
  formGroup.value?.$el?.scrollIntoView?.({
    behavior: 'smooth',
    block: 'start',
  });
};

const startNew = async () => {
  error.value = '';
  form.value = emptyForm();
  await loadOwnHours(null);
};

// Passar a «horário só desta agenda» começa pela semana do horário que se usava,
// em vez de uma semana vazia.
watch(
  () => form.value?.scheduleId,
  async (scheduleId, previous) => {
    if (scheduleId !== OWN || !previous || previous === OWN) return;
    if (form.value?.id) await loadOwnHours(form.value.id);
    const previousSchedule = schedules.value.find(
      schedule => schedule.id === previous
    );
    if (!ownHours.value.weekly.length && previousSchedule) {
      ownHours.value = {
        weekly: JSON.parse(JSON.stringify(previousSchedule.weekly)),
        overrides: [],
      };
    }
  }
);

const save = async () => {
  if (!form.value.name.trim()) {
    error.value = t('CALENDAR_SETUP.RESOURCES.NAME_REQUIRED');
    return;
  }
  isSaving.value = true;
  error.value = '';
  const existing = resources.value.find(item => item.id === form.value.id);
  const settings = { ...(existing?.settings || {}) };
  if (form.value.feegowProfessionalId)
    settings.feegow = { professional_id: form.value.feegowProfessionalId };
  else delete settings.feegow;
  const resource = {
    name: form.value.name.trim(),
    resource_type: form.value.resourceType,
    user_id:
      form.value.resourceType === 'user' && form.value.userId
        ? Number(form.value.userId)
        : null,
    timezone:
      existing?.timezone || Intl.DateTimeFormat().resolvedOptions().timeZone,
    slot_interval_minutes: form.value.slotInterval
      ? Number(form.value.slotInterval)
      : null,
    schedule_id: form.value.scheduleId === OWN ? null : form.value.scheduleId,
    settings,
  };
  try {
    const { data } = form.value.id
      ? await CalendarAPI.updateResource(form.value.id, { resource })
      : await CalendarAPI.createResource({ resource });
    const ownChanged = JSON.stringify(ownHours.value) !== savedOwnHours.value;
    if (form.value.scheduleId === OWN && (ownChanged || !form.value.id)) {
      await CalendarAPI.updateResourceWorkingHours(data.id, ownHours.value);
    }
    await Promise.all([loadResources(), loadSchedules()]);
    form.value = null;
  } catch (saveError) {
    error.value = apiErrorMessage(
      saveError,
      t('CALENDAR_SETUP.COMMON.SAVE_ERROR')
    );
  } finally {
    isSaving.value = false;
  }
};

const archive = async () => {
  // eslint-disable-next-line no-alert
  if (
    !window.confirm(
      t('CALENDAR_SETUP.RESOURCES.ARCHIVE_CONFIRM', { name: form.value.name })
    )
  )
    return;
  isSaving.value = true;
  try {
    await CalendarAPI.archiveResource(form.value.id);
    await Promise.all([loadResources(), loadSchedules()]);
    form.value = null;
  } catch (archiveError) {
    error.value = apiErrorMessage(
      archiveError,
      t('CALENDAR_SETUP.COMMON.SAVE_ERROR')
    );
  } finally {
    isSaving.value = false;
  }
};

onMounted(async () => {
  store.dispatch('agents/get');
  await Promise.all([
    resources.value.length ? null : loadResources(),
    schedules.value.length ? null : loadSchedules(),
    loadExtras(),
  ]);
  form.value = emptyForm();
  await loadOwnHours(null);
});
</script>

<template>
  <section
    class="grid content-start gap-4 px-5 py-[18px]"
    data-testid="calendar-setup-resources"
  >
    <SetupHead
      :title="t('CALENDAR_SETUP.RESOURCES.TITLE')"
      :description="t('CALENDAR_SETUP.RESOURCES.DESCRIPTION')"
    >
      <SetupButton
        variant="primary"
        :label="t('CALENDAR_SETUP.RESOURCES.NEW')"
        data-testid="calendar-resource-new"
        @click="startNew"
      />
    </SetupHead>

    <SetupGroup
      :title="t('CALENDAR_SETUP.RESOURCES.PROFESSIONALS')"
      :hint="String(professionals.length)"
      flush
    >
      <p
        v-if="!professionals.length"
        class="mb-0 py-2.5 text-ui text-n-slate-10"
      >
        {{ t('CALENDAR_SETUP.RESOURCES.EMPTY') }}
      </p>
      <SetupRow
        v-for="resource in professionals"
        :key="resource.id"
        clickable
        :title="resource.name"
        :hint="hintFor(resource)"
        :data-testid="`calendar-resource-row-${resource.id}`"
        @select="edit(resource)"
      >
        <SetupPill
          v-if="resource.missing_hours"
          tone="warn"
          :label="t('CALENDAR_SETUP.RESOURCES.MISSING_PILL')"
        />
        <SetupPill
          v-if="
            ['connected', 'error'].includes(resource.google_calendar_status)
          "
          :tone="
            resource.google_calendar_status === 'connected' ? 'google' : 'warn'
          "
          :label="t('CALENDAR_SETUP.RESOURCES.GOOGLE')"
        />
        <SetupPill
          v-if="resource.feegow_professional_id"
          tone="feegow"
          :label="t('CALENDAR_SETUP.RESOURCES.FEEGOW')"
        />
      </SetupRow>
    </SetupGroup>

    <SetupGroup
      :title="t('CALENDAR_SETUP.RESOURCES.ROOMS_EQUIPMENT')"
      :hint="String(others.length)"
      flush
    >
      <p v-if="!others.length" class="mb-0 py-2.5 text-ui text-n-slate-10">
        {{ t('CALENDAR_SETUP.RESOURCES.EMPTY') }}
      </p>
      <SetupRow
        v-for="resource in others"
        :key="resource.id"
        clickable
        :title="resource.name"
        :hint="hintFor(resource)"
        :data-testid="`calendar-resource-row-${resource.id}`"
        @select="edit(resource)"
      >
        <SetupPill
          v-if="resource.missing_hours"
          tone="warn"
          :label="t('CALENDAR_SETUP.RESOURCES.MISSING_PILL')"
        />
        <SetupPill v-else :label="typeLabel(resource.resource_type)" />
      </SetupRow>
    </SetupGroup>

    <SetupGroup
      v-if="form"
      ref="formGroup"
      :title="
        form.id
          ? t('CALENDAR_SETUP.RESOURCES.EDIT_GROUP', { name: form.name })
          : t('CALENDAR_SETUP.RESOURCES.NEW_GROUP')
      "
      :hint="form.id ? '' : t('CALENDAR_SETUP.RESOURCES.NEW_GROUP_HINT')"
      data-testid="calendar-resource-form"
    >
      <div class="grid gap-3 md:grid-cols-3">
        <RaevoField compact :label="t('CALENDAR_SETUP.RESOURCES.NAME')">
          <template #default="{ controlClass, fieldId }">
            <input
              :id="fieldId"
              v-model="form.name"
              type="text"
              :class="controlClass"
              :placeholder="t('CALENDAR_SETUP.RESOURCES.NAME_PLACEHOLDER')"
              data-testid="calendar-resource-name"
            />
          </template>
        </RaevoField>
        <RaevoField
          compact
          variant="select"
          :label="t('CALENDAR_SETUP.RESOURCES.TYPE')"
        >
          <template #default="{ controlClass, fieldId }">
            <select
              :id="fieldId"
              v-model="form.resourceType"
              :class="controlClass"
              data-testid="calendar-resource-type"
            >
              <option
                v-for="type in ['user', 'room', 'equipment', 'generic']"
                :key="type"
                :value="type"
              >
                {{ t(`CALENDAR_SETUP.RESOURCES.TYPES.${type.toUpperCase()}`) }}
              </option>
            </select>
          </template>
        </RaevoField>
        <RaevoField
          compact
          variant="select"
          :label="t('CALENDAR_SETUP.RESOURCES.CRM_USER')"
        >
          <template #default="{ controlClass, fieldId }">
            <select
              :id="fieldId"
              v-model="form.userId"
              :class="controlClass"
              :disabled="form.resourceType !== 'user'"
            >
              <option value="">
                {{ t('CALENDAR_SETUP.RESOURCES.OPTIONAL') }}
              </option>
              <option
                v-for="agent in agents"
                :key="agent.id"
                :value="String(agent.id)"
              >
                {{ agent.name || agent.email }}
              </option>
            </select>
          </template>
        </RaevoField>
      </div>

      <div class="grid gap-3 md:grid-cols-2">
        <RaevoField
          compact
          variant="select"
          :label="t('CALENDAR_SETUP.RESOURCES.SCHEDULE')"
          :hint="t('CALENDAR_SETUP.RESOURCES.SCHEDULE_HINT')"
        >
          <template #default="{ controlClass, fieldId, describedBy }">
            <select
              :id="fieldId"
              v-model="form.scheduleId"
              :class="controlClass"
              :aria-describedby="describedBy"
              data-testid="calendar-resource-schedule"
            >
              <option
                v-for="schedule in schedules"
                :key="schedule.id"
                :value="schedule.id"
              >
                {{
                  schedule.default
                    ? t('CALENDAR_SETUP.RESOURCES.SCHEDULE_DEFAULT', {
                        name: schedule.name,
                      })
                    : schedule.name
                }}
              </option>
              <option :value="OWN">
                {{ t('CALENDAR_SETUP.RESOURCES.OWN_OPTION') }}
              </option>
            </select>
          </template>
        </RaevoField>
        <RaevoField
          compact
          variant="select"
          :label="t('CALENDAR_SETUP.RESOURCES.SPACING_LABEL')"
        >
          <template #default="{ controlClass, fieldId }">
            <select
              :id="fieldId"
              v-model="form.slotInterval"
              :class="controlClass"
            >
              <option value="">
                {{
                  t('CALENDAR_SETUP.RESOURCES.ACCOUNT_DEFAULT', {
                    count: accountInterval,
                  })
                }}
              </option>
              <option
                v-for="interval in SLOT_INTERVALS"
                :key="interval"
                :value="String(interval)"
              >
                {{ t('CALENDAR_SETUP.COMMON.MINUTES', { count: interval }) }}
              </option>
            </select>
          </template>
        </RaevoField>
      </div>

      <div
        v-if="form.scheduleId === OWN"
        class="grid gap-3 rounded-lg border border-solid border-n-weak bg-n-surface-2 p-3"
        data-testid="calendar-resource-own-hours"
      >
        <strong class="text-ui font-semibold text-n-slate-12">{{
          t('CALENDAR_SETUP.RESOURCES.OWN_HOURS_TITLE')
        }}</strong>
        <WeekEditor v-model="ownHours.weekly" :disabled="isSaving" />
        <strong class="text-ui font-semibold text-n-slate-12">{{
          t('CALENDAR_SETUP.SCHEDULES.EXCEPTIONS')
        }}</strong>
        <ExceptionsEditor v-model="ownHours.overrides" :disabled="isSaving" />
      </div>

      <RaevoField
        v-if="feegowProfessionals.length && form.resourceType === 'user'"
        compact
        variant="select"
        :label="t('CALENDAR.SETTINGS.FEEGOW.PROFESSIONAL')"
        :hint="t('CALENDAR.SETTINGS.FEEGOW.PROFESSIONAL_HINT')"
      >
        <template #default="{ controlClass, fieldId, describedBy }">
          <select
            :id="fieldId"
            v-model="form.feegowProfessionalId"
            :class="controlClass"
            :aria-describedby="describedBy"
            data-testid="calendar-resource-feegow-professional"
          >
            <option value="">
              {{ t('CALENDAR.SETTINGS.FEEGOW.NO_PROFESSIONAL') }}
            </option>
            <option
              v-for="professional in feegowProfessionals"
              :key="professional.id"
              :value="String(professional.id)"
            >
              {{ professional.name }}
            </option>
          </select>
        </template>
      </RaevoField>

      <ResourceGoogleConnection
        v-if="form.id && form.resourceType === 'user'"
        :resource-id="form.id"
        @changed="loadResources"
      />

      <p v-if="error" class="mb-0 text-ui text-n-ruby-11" role="alert">
        {{ error }}
      </p>

      <div class="flex flex-wrap items-center justify-between gap-2">
        <SetupButton
          v-if="form.id"
          :label="t('CALENDAR_SETUP.RESOURCES.ARCHIVE')"
          :disabled="isSaving"
          @click="archive"
        />
        <span v-else />
        <span class="flex gap-2">
          <SetupButton
            v-if="form.id"
            :label="t('CALENDAR_SETUP.COMMON.CANCEL')"
            @click="startNew"
          />
          <SetupButton
            variant="primary"
            :label="
              form.id
                ? t('CALENDAR_SETUP.COMMON.SAVE')
                : t('CALENDAR_SETUP.RESOURCES.CREATE')
            "
            :loading="isSaving"
            data-testid="calendar-resource-save"
            @click="save"
          />
        </span>
      </div>
    </SetupGroup>
  </section>
</template>
