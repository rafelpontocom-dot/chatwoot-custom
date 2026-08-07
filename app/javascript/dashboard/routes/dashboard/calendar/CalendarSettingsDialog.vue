<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';

import CalendarAPI from 'dashboard/api/calendar';
import NextButton from 'dashboard/components-next/button/Button.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const emit = defineEmits(['updated']);

const { t } = useI18n();
const dialog = ref(null);
const activeTab = ref('procedures');
const procedures = ref([]);
const resources = ref([]);
const availabilityResourceId = ref(null);
const availabilityRules = ref([]);
const isLoadingAvailability = ref(false);
const isLoading = ref(false);
const isSaving = ref(false);
const error = ref('');
const procedureForm = ref({
  name: '',
  durationMinutes: '50',
  recurrenceAllowed: false,
  maxSessions: '',
  resourceIds: [],
});
const resourceForm = ref({ name: '', resourceType: 'generic' });
const availabilityForm = ref({
  weekday: '1',
  startsAtLocal: '09:00',
  endsAtLocal: '18:00',
});

const canCreateProcedure = computed(
  () =>
    procedureForm.value.name.trim() &&
    Number(procedureForm.value.durationMinutes) > 0 &&
    !isSaving.value
);
const canCreateResource = computed(
  () => resourceForm.value.name.trim() && !isSaving.value
);
const resourceTypeLabel = resourceType =>
  ({
    room: t('CALENDAR.SETTINGS.RESOURCE_TYPES.ROOM'),
    equipment: t('CALENDAR.SETTINGS.RESOURCE_TYPES.EQUIPMENT'),
    generic: t('CALENDAR.SETTINGS.RESOURCE_TYPES.GENERIC'),
  })[resourceType] || t('CALENDAR.SETTINGS.RESOURCE_TYPES.GENERIC');
const availabilityResource = computed(() =>
  resources.value.find(resource => resource.id === availabilityResourceId.value)
);
const resourceOptions = computed(() =>
  resources.value
    .filter(resource => resource.active)
    .map(resource => ({
      value: resource.id,
      label: resource.name,
    }))
);
const orderedAvailabilityRules = computed(() =>
  [...availabilityRules.value].sort((firstRule, secondRule) => {
    if (firstRule.weekday !== secondRule.weekday) {
      return firstRule.weekday - secondRule.weekday;
    }

    return firstRule.starts_at_local.localeCompare(secondRule.starts_at_local);
  })
);
const weekdayLabel = weekday =>
  [
    t('CALENDAR.SETTINGS.WEEKDAYS.SUNDAY'),
    t('CALENDAR.SETTINGS.WEEKDAYS.MONDAY'),
    t('CALENDAR.SETTINGS.WEEKDAYS.TUESDAY'),
    t('CALENDAR.SETTINGS.WEEKDAYS.WEDNESDAY'),
    t('CALENDAR.SETTINGS.WEEKDAYS.THURSDAY'),
    t('CALENDAR.SETTINGS.WEEKDAYS.FRIDAY'),
    t('CALENDAR.SETTINGS.WEEKDAYS.SATURDAY'),
  ][weekday];

const getErrorMessage = errorResponse =>
  errorResponse?.response?.data?.message ||
  errorResponse?.message ||
  t('CALENDAR.SETTINGS.SAVE_ERROR');

const resetForms = () => {
  procedureForm.value = {
    name: '',
    durationMinutes: '50',
    recurrenceAllowed: false,
    maxSessions: '',
    resourceIds: [],
  };
  resourceForm.value = { name: '', resourceType: 'generic' };
  availabilityResourceId.value = null;
  availabilityRules.value = [];
  availabilityForm.value = {
    weekday: '1',
    startsAtLocal: '09:00',
    endsAtLocal: '18:00',
  };
  error.value = '';
};

const loadSettings = async () => {
  isLoading.value = true;
  error.value = '';

  try {
    const [proceduresResponse, resourcesResponse] = await Promise.all([
      CalendarAPI.getProcedures(),
      CalendarAPI.getResources(),
    ]);
    procedures.value = proceduresResponse.data || [];
    resources.value = resourcesResponse.data || [];
  } catch (loadError) {
    error.value = getErrorMessage(loadError);
  } finally {
    isLoading.value = false;
  }
};

const open = async () => {
  resetForms();
  dialog.value?.open();
  await loadSettings();
};

const close = () => dialog.value?.close();

const createProcedure = async () => {
  if (!canCreateProcedure.value) return;

  isSaving.value = true;
  error.value = '';
  try {
    const procedure = {
      name: procedureForm.value.name.trim(),
      duration_minutes: Number(procedureForm.value.durationMinutes),
      recurrence_allowed: procedureForm.value.recurrenceAllowed,
      resource_ids: procedureForm.value.resourceIds.map(Number),
      active: true,
    };
    if (procedure.recurrence_allowed && procedureForm.value.maxSessions) {
      procedure.max_sessions = Number(procedureForm.value.maxSessions);
    }
    const response = await CalendarAPI.createProcedure({ procedure });
    procedures.value = [...procedures.value, response.data];
    procedureForm.value = {
      name: '',
      durationMinutes: '50',
      recurrenceAllowed: false,
      maxSessions: '',
      resourceIds: [],
    };
    emit('updated');
  } catch (saveError) {
    error.value = getErrorMessage(saveError);
  } finally {
    isSaving.value = false;
  }
};

const createResource = async () => {
  if (!canCreateResource.value) return;

  isSaving.value = true;
  error.value = '';
  try {
    const resource = {
      name: resourceForm.value.name.trim(),
      resource_type: resourceForm.value.resourceType,
      timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
      active: true,
    };
    const response = await CalendarAPI.createResource({ resource });
    resources.value = [...resources.value, response.data];
    resourceForm.value = { name: '', resourceType: 'generic' };
    emit('updated');
  } catch (saveError) {
    error.value = getErrorMessage(saveError);
  } finally {
    isSaving.value = false;
  }
};

const loadAvailabilityRules = async resourceId => {
  if (!resourceId) return;

  isLoadingAvailability.value = true;
  error.value = '';
  try {
    const response = await CalendarAPI.getAvailabilityRules(resourceId);
    availabilityRules.value = response.data || [];
  } catch (loadError) {
    error.value = getErrorMessage(loadError);
  } finally {
    isLoadingAvailability.value = false;
  }
};

const openAvailability = async resource => {
  availabilityResourceId.value = resource.id;
  await loadAvailabilityRules(resource.id);
};

const addWeeklyAvailability = async () => {
  if (!availabilityResourceId.value || isSaving.value) return;

  isSaving.value = true;
  error.value = '';
  try {
    const response = await CalendarAPI.createAvailabilityRule(
      availabilityResourceId.value,
      {
        availability_rule: {
          kind: 'weekly_window',
          weekday: Number(availabilityForm.value.weekday),
          starts_at_local: availabilityForm.value.startsAtLocal,
          ends_at_local: availabilityForm.value.endsAtLocal,
          active: true,
        },
      }
    );
    availabilityRules.value = [...availabilityRules.value, response.data];
  } catch (saveError) {
    error.value = getErrorMessage(saveError);
  } finally {
    isSaving.value = false;
  }
};

const removeAvailabilityRule = async rule => {
  if (!availabilityResourceId.value || isSaving.value) return;

  isSaving.value = true;
  error.value = '';
  try {
    await CalendarAPI.deleteAvailabilityRule(
      availabilityResourceId.value,
      rule.id
    );
    availabilityRules.value = availabilityRules.value.filter(
      item => item.id !== rule.id
    );
  } catch (saveError) {
    error.value = getErrorMessage(saveError);
  } finally {
    isSaving.value = false;
  }
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialog"
    width="lg"
    overflow-y-auto
    :title="t('CALENDAR.SETTINGS.TITLE')"
    :description="t('CALENDAR.SETTINGS.DESCRIPTION')"
    :show-confirm-button="false"
    @close="resetForms"
  >
    <div class="grid gap-4">
      <div
        class="inline-flex w-fit rounded-md border border-n-weak bg-n-surface-2 p-0.5"
        role="tablist"
        :aria-label="t('CALENDAR.SETTINGS.TABS_LABEL')"
      >
        <button
          type="button"
          class="rounded px-3 py-1.5 text-sm font-medium outline-none focus:ring-2 focus:ring-n-brand/40"
          :class="
            activeTab === 'procedures'
              ? 'bg-n-surface-1 text-n-slate-12 shadow-sm'
              : 'text-n-slate-11'
          "
          :aria-selected="activeTab === 'procedures'"
          @click="activeTab = 'procedures'"
        >
          {{ t('CALENDAR.SETTINGS.PROCEDURES') }}
        </button>
        <button
          type="button"
          class="rounded px-3 py-1.5 text-sm font-medium outline-none focus:ring-2 focus:ring-n-brand/40"
          :class="
            activeTab === 'resources'
              ? 'bg-n-surface-1 text-n-slate-12 shadow-sm'
              : 'text-n-slate-11'
          "
          :aria-selected="activeTab === 'resources'"
          @click="activeTab = 'resources'"
        >
          {{ t('CALENDAR.SETTINGS.RESOURCES') }}
        </button>
      </div>

      <p v-if="isLoading" class="mb-0 text-sm text-n-slate-11">
        {{ t('CALENDAR.SETTINGS.LOADING') }}
      </p>
      <p v-else-if="error" class="mb-0 text-sm text-n-ruby-11" role="alert">
        {{ error }}
      </p>

      <template v-else-if="activeTab === 'procedures'">
        <form
          class="grid gap-3 rounded-lg border border-n-weak bg-n-surface-2 p-3"
          @submit.prevent="createProcedure"
        >
          <div class="grid gap-3 sm:grid-cols-[minmax(0,1fr)_8rem]">
            <label class="grid gap-1.5">
              <span class="text-sm font-medium text-n-slate-12">
                {{ t('CALENDAR.SETTINGS.PROCEDURE_NAME') }}
              </span>
              <input
                v-model="procedureForm.name"
                type="text"
                class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
              />
            </label>
            <label class="grid gap-1.5">
              <span class="text-sm font-medium text-n-slate-12">
                {{ t('CALENDAR.SETTINGS.DURATION') }}
              </span>
              <input
                v-model="procedureForm.durationMinutes"
                min="5"
                max="480"
                type="number"
                class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
              />
            </label>
          </div>
          <label class="grid gap-1.5">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('CALENDAR.SETTINGS.PROCEDURE_RESOURCES') }}
            </span>
            <TagMultiSelectComboBox
              v-model="procedureForm.resourceIds"
              :options="resourceOptions"
              :placeholder="
                t('CALENDAR.SETTINGS.PROCEDURE_RESOURCES_PLACEHOLDER')
              "
              :search-placeholder="
                t('CALENDAR.SETTINGS.PROCEDURE_RESOURCES_SEARCH')
              "
              :empty-state="t('CALENDAR.SETTINGS.PROCEDURE_RESOURCES_EMPTY')"
            />
            <span class="text-xs font-normal text-n-slate-11">
              {{ t('CALENDAR.SETTINGS.PROCEDURE_RESOURCES_HELP') }}
            </span>
          </label>
          <div class="flex flex-wrap items-center justify-between gap-3">
            <label class="flex items-center gap-2 text-sm text-n-slate-12">
              <input
                v-model="procedureForm.recurrenceAllowed"
                type="checkbox"
                class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
              />
              {{ t('CALENDAR.SETTINGS.ALLOW_RECURRENCE') }}
            </label>
            <label
              v-if="procedureForm.recurrenceAllowed"
              class="flex items-center gap-2 text-sm text-n-slate-12"
            >
              <span>{{ t('CALENDAR.SETTINGS.MAX_SESSIONS') }}</span>
              <input
                v-model="procedureForm.maxSessions"
                min="2"
                max="100"
                type="number"
                class="h-8 w-20 rounded-md border border-n-weak bg-n-surface-1 px-2 text-sm outline-none focus:border-n-brand"
              />
            </label>
            <NextButton
              type="submit"
              size="sm"
              :label="t('CALENDAR.SETTINGS.ADD_PROCEDURE')"
              :disabled="!canCreateProcedure"
              :is-loading="isSaving"
            />
          </div>
        </form>
        <div class="grid gap-2">
          <p v-if="!procedures.length" class="mb-0 text-sm text-n-slate-11">
            {{ t('CALENDAR.SETTINGS.NO_PROCEDURES') }}
          </p>
          <article
            v-for="procedure in procedures"
            :key="procedure.id"
            class="flex items-center justify-between gap-3 rounded-md border border-n-weak px-3 py-2"
          >
            <span class="text-sm font-medium text-n-slate-12">{{
              procedure.name
            }}</span>
            <span class="text-xs text-n-slate-11">
              {{
                t('CALENDAR.SETTINGS.DURATION_VALUE', {
                  minutes: procedure.duration_minutes,
                })
              }}
            </span>
          </article>
        </div>
      </template>

      <template v-else>
        <form
          class="grid gap-3 rounded-lg border border-n-weak bg-n-surface-2 p-3"
          @submit.prevent="createResource"
        >
          <div
            class="grid gap-3 sm:grid-cols-[minmax(0,1fr)_10rem_auto] sm:items-end"
          >
            <label class="grid gap-1.5">
              <span class="text-sm font-medium text-n-slate-12">
                {{ t('CALENDAR.SETTINGS.RESOURCE_NAME') }}
              </span>
              <input
                v-model="resourceForm.name"
                type="text"
                class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
              />
            </label>
            <label class="grid gap-1.5">
              <span class="text-sm font-medium text-n-slate-12">
                {{ t('CALENDAR.SETTINGS.RESOURCE_TYPE') }}
              </span>
              <select
                v-model="resourceForm.resourceType"
                class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
              >
                <option value="room">
                  {{ t('CALENDAR.SETTINGS.RESOURCE_TYPES.ROOM') }}
                </option>
                <option value="equipment">
                  {{ t('CALENDAR.SETTINGS.RESOURCE_TYPES.EQUIPMENT') }}
                </option>
                <option value="generic">
                  {{ t('CALENDAR.SETTINGS.RESOURCE_TYPES.GENERIC') }}
                </option>
              </select>
            </label>
            <NextButton
              type="submit"
              size="sm"
              :label="t('CALENDAR.SETTINGS.ADD_RESOURCE')"
              :disabled="!canCreateResource"
              :is-loading="isSaving"
            />
          </div>
        </form>
        <div class="grid gap-2">
          <p v-if="!resources.length" class="mb-0 text-sm text-n-slate-11">
            {{ t('CALENDAR.SETTINGS.NO_RESOURCES') }}
          </p>
          <article
            v-for="resource in resources"
            :key="resource.id"
            class="flex items-center justify-between gap-3 rounded-md border border-n-weak px-3 py-2"
          >
            <div class="grid gap-0.5">
              <span class="text-sm font-medium text-n-slate-12">{{
                resource.name
              }}</span>
              <span class="text-xs text-n-slate-11">
                {{ resourceTypeLabel(resource.resource_type) }}
              </span>
            </div>
            <NextButton
              type="button"
              xs
              outline
              :label="t('CALENDAR.SETTINGS.AVAILABILITY.OPEN')"
              @click="openAvailability(resource)"
            />
          </article>
        </div>

        <section
          v-if="availabilityResource"
          class="grid gap-3 rounded-lg border border-n-weak bg-n-surface-2 p-3"
        >
          <div class="flex items-center justify-between gap-3">
            <div class="grid gap-0.5">
              <h3 class="mb-0 text-sm font-medium text-n-slate-12">
                {{ t('CALENDAR.SETTINGS.AVAILABILITY.TITLE') }}
              </h3>
              <p class="mb-0 text-xs text-n-slate-11">
                {{ availabilityResource.name }}
              </p>
            </div>
            <NextButton
              type="button"
              xs
              ghost
              icon="i-lucide-x"
              :label="t('CALENDAR.SETTINGS.AVAILABILITY.CLOSE')"
              @click="availabilityResourceId = null"
            />
          </div>
          <p class="mb-0 text-xs text-n-slate-11">
            {{ t('CALENDAR.SETTINGS.AVAILABILITY.HELP') }}
          </p>
          <form
            class="grid gap-2 sm:grid-cols-[minmax(0,1fr)_7rem_7rem_auto] sm:items-end"
            @submit.prevent="addWeeklyAvailability"
          >
            <label class="grid gap-1">
              <span class="text-xs font-medium text-n-slate-12">{{
                t('CALENDAR.SETTINGS.AVAILABILITY.WEEKDAY')
              }}</span>
              <select
                v-model="availabilityForm.weekday"
                class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
              >
                <option
                  v-for="weekday in 7"
                  :key="weekday - 1"
                  :value="String(weekday - 1)"
                >
                  {{ weekdayLabel(weekday - 1) }}
                </option>
              </select>
            </label>
            <label class="grid gap-1">
              <span class="text-xs font-medium text-n-slate-12">{{
                t('CALENDAR.SETTINGS.AVAILABILITY.START')
              }}</span>
              <input
                v-model="availabilityForm.startsAtLocal"
                type="time"
                class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
              />
            </label>
            <label class="grid gap-1">
              <span class="text-xs font-medium text-n-slate-12">{{
                t('CALENDAR.SETTINGS.AVAILABILITY.END')
              }}</span>
              <input
                v-model="availabilityForm.endsAtLocal"
                type="time"
                class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
              />
            </label>
            <NextButton
              type="submit"
              size="sm"
              :label="t('CALENDAR.SETTINGS.AVAILABILITY.ADD')"
              :disabled="isSaving"
            />
          </form>
          <p v-if="isLoadingAvailability" class="mb-0 text-sm text-n-slate-11">
            {{ t('CALENDAR.SETTINGS.AVAILABILITY.LOADING') }}
          </p>
          <div v-else class="grid gap-1.5">
            <p
              v-if="!orderedAvailabilityRules.length"
              class="mb-0 text-sm text-n-slate-11"
            >
              {{ t('CALENDAR.SETTINGS.AVAILABILITY.EMPTY') }}
            </p>
            <div
              v-for="rule in orderedAvailabilityRules"
              :key="rule.id"
              class="flex items-center justify-between gap-2 rounded-md bg-n-surface-1 px-2.5 py-2 text-sm text-n-slate-12"
            >
              <span>
                {{
                  t('CALENDAR.SETTINGS.AVAILABILITY.RULE', {
                    weekday: weekdayLabel(rule.weekday),
                    start: rule.starts_at_local,
                    end: rule.ends_at_local,
                  })
                }}
              </span>
              <NextButton
                type="button"
                xs
                ghost
                icon="i-lucide-trash-2"
                :label="t('CALENDAR.SETTINGS.AVAILABILITY.REMOVE')"
                @click="removeAvailabilityRule(rule)"
              />
            </div>
          </div>
        </section>
      </template>
    </div>

    <template #footer>
      <div class="flex justify-end">
        <NextButton
          type="button"
          link
          slate
          :label="t('GENERAL.CLOSE')"
          @click="close"
        />
      </div>
    </template>
  </Dialog>
</template>
