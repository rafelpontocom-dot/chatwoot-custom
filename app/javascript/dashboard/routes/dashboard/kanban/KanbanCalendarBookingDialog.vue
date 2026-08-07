<script setup>
import { computed, onUnmounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import camelcaseKeys from 'camelcase-keys';
import { debounce } from '@chatwoot/utils';

import CalendarAPI from 'dashboard/api/calendar';
import ContactAPI from 'dashboard/api/contacts';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const props = defineProps({
  cardId: { type: [Number, String], default: null },
  contactId: { type: [Number, String], default: null },
  contactName: { type: String, default: '' },
  selectContact: { type: Boolean, default: false },
  allowedProcedureIds: { type: Array, default: () => [] },
});

const emit = defineEmits(['created']);

const { t } = useI18n();
const dialog = ref(null);
const procedures = ref([]);
const resources = ref([]);
const procedureId = ref('');
const resourceId = ref('');
const startsAt = ref('');
const occurrenceCount = ref('1');
const intervalKind = ref('weekly');
const intervalDays = ref('');
const isLoading = ref(false);
const isSaving = ref(false);
const error = ref('');
const contactSearchQuery = ref('');
const contactResults = ref([]);
const selectedContact = ref(null);
const isSearchingContacts = ref(false);
const contactSearchController = ref(null);
const availabilityAppointments = ref([]);
const isCheckingAvailability = ref(false);

const bookingContactId = computed(
  () => props.contactId || selectedContact.value?.id
);
const bookingContactName = computed(
  () => props.contactName || selectedContact.value?.name || ''
);

const selectedProcedure = computed(() =>
  procedures.value.find(procedure => String(procedure.id) === procedureId.value)
);
const availableResources = computed(() => {
  const allowedIds = selectedProcedure.value?.resource_ids || [];

  if (!allowedIds.length) return resources.value;

  return resources.value.filter(resource => allowedIds.includes(resource.id));
});
const recurrenceIntervals = computed(() => {
  const allowedIntervals = selectedProcedure.value?.allowed_intervals || [];
  const intervals = allowedIntervals.length
    ? allowedIntervals
    : ['weekly', 'biweekly', 'monthly'];

  return [
    ...new Set(
      intervals.map(interval => interval.replace(/^days:\\d+$/, 'days'))
    ),
  ];
});
const recurrenceEnabled = computed(
  () =>
    Number(occurrenceCount.value) > 1 &&
    selectedProcedure.value?.recurrence_allowed
);
const recurrenceIntervalLabel = interval =>
  ({
    weekly: t('CALENDAR.OPPORTUNITY.INTERVALS.WEEKLY'),
    biweekly: t('CALENDAR.OPPORTUNITY.INTERVALS.BIWEEKLY'),
    monthly: t('CALENDAR.OPPORTUNITY.INTERVALS.MONTHLY'),
    days: t('CALENDAR.OPPORTUNITY.INTERVALS.DAYS'),
  })[interval] || interval;
const requestedEndsAt = computed(() => {
  if (!startsAt.value || !selectedProcedure.value?.duration_minutes)
    return null;

  return new Date(
    new Date(startsAt.value).getTime() +
      selectedProcedure.value.duration_minutes * 60 * 1000
  );
});
const hasAvailabilityConflict = computed(() => {
  if (!requestedEndsAt.value) return false;

  const requestedStartsAt = new Date(startsAt.value);
  return availabilityAppointments.value.some(appointment => {
    const appointmentStartsAt = new Date(appointment.starts_at);
    const appointmentEndsAt = new Date(appointment.ends_at);
    return (
      appointmentStartsAt < requestedEndsAt.value &&
      appointmentEndsAt > requestedStartsAt
    );
  });
});
const canSave = computed(
  () =>
    !!bookingContactId.value &&
    !!procedureId.value &&
    !!resourceId.value &&
    !!startsAt.value &&
    !hasAvailabilityConflict.value &&
    (!recurrenceEnabled.value ||
      intervalKind.value !== 'days' ||
      Number(intervalDays.value) > 0) &&
    !isSaving.value
);

const resetForm = () => {
  procedureId.value = '';
  resourceId.value = '';
  startsAt.value = '';
  occurrenceCount.value = '1';
  intervalKind.value = 'weekly';
  intervalDays.value = '';
  error.value = '';
  contactSearchQuery.value = '';
  contactResults.value = [];
  selectedContact.value = null;
  availabilityAppointments.value = [];
  isCheckingAvailability.value = false;
};

const abortContactSearch = () => {
  contactSearchController.value?.abort();
  contactSearchController.value = null;
};

const searchContacts = async query => {
  const trimmedQuery = query.trim();
  if (trimmedQuery.length < 2) {
    contactResults.value = [];
    return;
  }

  abortContactSearch();
  const controller = new AbortController();
  contactSearchController.value = controller;
  isSearchingContacts.value = true;

  try {
    const response = await ContactAPI.search(trimmedQuery, 1, 'name', '', {
      signal: controller.signal,
    });
    if (!controller.signal.aborted) {
      contactResults.value = camelcaseKeys(response.data?.payload || [], {
        deep: true,
      });
    }
  } catch (searchError) {
    if (
      searchError?.name !== 'AbortError' &&
      searchError?.name !== 'CanceledError'
    ) {
      contactResults.value = [];
    }
  } finally {
    if (contactSearchController.value === controller) {
      contactSearchController.value = null;
      isSearchingContacts.value = false;
    }
  }
};

const debouncedSearchContacts = debounce(searchContacts, 250, false);

const selectSearchContact = contact => {
  selectedContact.value = contact;
  contactSearchQuery.value =
    contact.name || contact.email || contact.phoneNumber || '';
  contactResults.value = [];
};

const onContactInput = () => {
  selectedContact.value = null;
  debouncedSearchContacts(contactSearchQuery.value);
};

const checkAvailability = async () => {
  if (!resourceId.value || !startsAt.value) {
    availabilityAppointments.value = [];
    return;
  }

  const selectedStartsAt = new Date(startsAt.value);
  const dayStart = new Date(selectedStartsAt);
  dayStart.setHours(0, 0, 0, 0);
  const dayEnd = new Date(dayStart);
  dayEnd.setDate(dayEnd.getDate() + 1);
  isCheckingAvailability.value = true;

  try {
    const response = await CalendarAPI.getAppointments({
      starts_at: dayStart.toISOString(),
      ends_at: dayEnd.toISOString(),
      resource_ids: [Number(resourceId.value)],
    });
    availabilityAppointments.value = response.data || [];
  } catch {
    availabilityAppointments.value = [];
  } finally {
    isCheckingAvailability.value = false;
  }
};

const debouncedCheckAvailability = debounce(checkAvailability, 250, false);

const getErrorMessage = errorResponse =>
  errorResponse?.response?.data?.message ||
  errorResponse?.message ||
  t('CALENDAR.OPPORTUNITY.SAVE_ERROR');

const loadOptions = async () => {
  isLoading.value = true;
  error.value = '';

  try {
    const [proceduresResponse, resourcesResponse] = await Promise.all([
      CalendarAPI.getProcedures(),
      CalendarAPI.getResources(),
    ]);
    procedures.value = (proceduresResponse.data || []).filter(
      procedure =>
        procedure.active &&
        (!props.allowedProcedureIds.length ||
          props.allowedProcedureIds.map(Number).includes(Number(procedure.id)))
    );
    resources.value = (resourcesResponse.data || []).filter(
      resource => resource.active
    );
  } catch (loadError) {
    error.value = getErrorMessage(loadError);
  } finally {
    isLoading.value = false;
  }
};

const open = async () => {
  resetForm();
  dialog.value?.open();
  await loadOptions();
};

const close = () => dialog.value?.close();

const save = async () => {
  if (!canSave.value) return;

  isSaving.value = true;
  error.value = '';

  try {
    const appointment = {
      contact_id: Number(bookingContactId.value),
      procedure_id: Number(procedureId.value),
      resource_ids: [Number(resourceId.value)],
      starts_at: new Date(startsAt.value).toISOString(),
      timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
    };
    if (recurrenceEnabled.value) {
      appointment.occurrence_count = Number(occurrenceCount.value);
      appointment.interval_kind = intervalKind.value;
      if (intervalKind.value === 'days') {
        appointment.interval_days = Number(intervalDays.value);
      }
    }
    if (props.cardId) appointment.kanban_card_id = Number(props.cardId);
    const response = await CalendarAPI.createAppointment({ appointment });
    emit('created', response.data);
    close();
  } catch (saveError) {
    error.value = getErrorMessage(saveError);
  } finally {
    isSaving.value = false;
  }
};

watch(availableResources, nextResources => {
  if (
    nextResources.some(resource => String(resource.id) === resourceId.value)
  ) {
    return;
  }

  resourceId.value = '';
});

watch(procedureId, () => {
  if (!selectedProcedure.value?.recurrence_allowed) {
    occurrenceCount.value = '1';
  }
  if (!recurrenceIntervals.value.includes(intervalKind.value)) {
    intervalKind.value = recurrenceIntervals.value[0] || 'weekly';
  }
});

watch([resourceId, startsAt], debouncedCheckAvailability);

onUnmounted(abortContactSearch);

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialog"
    width="md"
    overflow-y-auto
    :title="t('CALENDAR.OPPORTUNITY.BOOK_TITLE')"
    :description="
      t('CALENDAR.OPPORTUNITY.BOOK_DESCRIPTION', {
        contact: bookingContactName,
      })
    "
    :show-confirm-button="false"
    @close="resetForm"
  >
    <div class="grid gap-4">
      <p
        v-if="!bookingContactId && !selectContact"
        class="mb-0 rounded-md bg-n-ruby-2 px-3 py-2 text-sm text-n-ruby-11"
        role="alert"
      >
        {{ t('CALENDAR.OPPORTUNITY.CONTACT_REQUIRED') }}
      </p>

      <p v-else-if="isLoading" class="mb-0 text-sm text-n-slate-11">
        {{ t('CALENDAR.OPPORTUNITY.LOADING_OPTIONS') }}
      </p>

      <template v-else>
        <label v-if="selectContact" class="grid gap-1.5">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('CALENDAR.OPPORTUNITY.CONTACT') }}
          </span>
          <input
            v-model="contactSearchQuery"
            data-testid="calendar-appointment-contact-search"
            type="search"
            :placeholder="t('CALENDAR.OPPORTUNITY.SEARCH_CONTACT')"
            class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
            @input="onContactInput"
          />
          <span v-if="isSearchingContacts" class="text-xs text-n-slate-11">
            {{ t('CALENDAR.OPPORTUNITY.SEARCHING_CONTACT') }}
          </span>
          <div v-else-if="contactResults.length" class="grid gap-1">
            <button
              v-for="contact in contactResults"
              :key="contact.id"
              type="button"
              class="rounded-md px-2 py-1.5 text-left text-sm text-n-slate-12 outline-none hover:bg-n-alpha-2 focus:ring-2 focus:ring-n-brand/40"
              @click="selectSearchContact(contact)"
            >
              {{ contact.name || contact.email || contact.phoneNumber }}
            </button>
          </div>
        </label>

        <label class="grid gap-1.5">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('CALENDAR.OPPORTUNITY.PROCEDURE') }}
          </span>
          <select
            v-model="procedureId"
            data-testid="kanban-calendar-procedure"
            class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
          >
            <option value="">
              {{ t('CALENDAR.OPPORTUNITY.SELECT_PROCEDURE') }}
            </option>
            <option
              v-for="procedure in procedures"
              :key="procedure.id"
              :value="String(procedure.id)"
            >
              {{ procedure.name }}
            </option>
          </select>
        </label>

        <div
          v-if="selectedProcedure?.recurrence_allowed"
          class="grid gap-3 rounded-md border border-n-weak bg-n-surface-2 p-3 sm:grid-cols-[8rem_minmax(0,1fr)]"
        >
          <label class="grid gap-1.5">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('CALENDAR.OPPORTUNITY.SESSIONS') }}
            </span>
            <input
              v-model="occurrenceCount"
              data-testid="kanban-calendar-occurrence-count"
              type="number"
              min="1"
              :max="selectedProcedure.max_sessions || 100"
              :disabled="!selectedProcedure.recurrence_allowed"
              class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none disabled:cursor-not-allowed disabled:opacity-60 focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
            />
          </label>
          <label v-if="recurrenceEnabled" class="grid gap-1.5">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('CALENDAR.OPPORTUNITY.RECURRENCE') }}
            </span>
            <select
              v-model="intervalKind"
              data-testid="kanban-calendar-interval-kind"
              class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
            >
              <option
                v-for="interval in recurrenceIntervals"
                :key="interval"
                :value="interval"
              >
                {{ recurrenceIntervalLabel(interval) }}
              </option>
            </select>
          </label>
          <label
            v-if="recurrenceEnabled && intervalKind === 'days'"
            class="grid gap-1.5 sm:col-span-2"
          >
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('CALENDAR.OPPORTUNITY.INTERVAL_DAYS') }}
            </span>
            <input
              v-model="intervalDays"
              data-testid="kanban-calendar-interval-days"
              type="number"
              min="1"
              class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
            />
          </label>
        </div>

        <label class="grid gap-1.5">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('CALENDAR.OPPORTUNITY.RESOURCE') }}
          </span>
          <select
            v-model="resourceId"
            data-testid="kanban-calendar-resource"
            :disabled="!procedureId"
            class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none disabled:cursor-not-allowed disabled:opacity-60 focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
          >
            <option value="">
              {{ t('CALENDAR.OPPORTUNITY.SELECT_RESOURCE') }}
            </option>
            <option
              v-for="resource in availableResources"
              :key="resource.id"
              :value="String(resource.id)"
            >
              {{ resource.name }}
            </option>
          </select>
        </label>

        <label class="grid gap-1.5">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('CALENDAR.OPPORTUNITY.STARTS_AT') }}
          </span>
          <input
            v-model="startsAt"
            data-testid="kanban-calendar-starts-at"
            type="datetime-local"
            class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
          />
        </label>
        <p v-if="isCheckingAvailability" class="mb-0 text-xs text-n-slate-11">
          {{ t('CALENDAR.OPPORTUNITY.CHECKING_AVAILABILITY') }}
        </p>
        <p
          v-else-if="hasAvailabilityConflict"
          class="mb-0 text-sm text-n-ruby-11"
          role="alert"
        >
          {{ t('CALENDAR.OPPORTUNITY.AVAILABILITY_CONFLICT') }}
        </p>
      </template>

      <p v-if="error" class="mb-0 text-sm text-n-ruby-11" role="alert">
        {{ error }}
      </p>
    </div>

    <template #footer>
      <div class="flex items-center justify-end gap-3">
        <NextButton
          type="button"
          link
          slate
          :label="t('DIALOG.BUTTONS.CANCEL')"
          @click="close"
        />
        <NextButton
          type="button"
          :label="t('CALENDAR.OPPORTUNITY.CONFIRM_BOOKING')"
          :disabled="!canSave || isLoading"
          :is-loading="isSaving"
          @click="save"
        />
      </div>
    </template>
  </Dialog>
</template>
