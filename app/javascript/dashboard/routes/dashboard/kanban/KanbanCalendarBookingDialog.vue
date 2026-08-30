<script setup>
import { computed, onUnmounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import camelcaseKeys from 'camelcase-keys';
import { debounce } from '@chatwoot/utils';

import CalendarAPI from 'dashboard/api/calendar';
import ContactAPI from 'dashboard/api/contacts';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import RaevoField from 'dashboard/components-next/raevo/RaevoField.vue';

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
const availabilityResult = ref(null);
const isCheckingAvailability = ref(false);
const availabilitySlots = ref([]);
const isLoadingSlots = ref(false);

const bookingContactId = computed(
  () => props.contactId || selectedContact.value?.id
);
const bookingContactName = computed(
  () => props.contactName || selectedContact.value?.name || ''
);
const bookingDescription = computed(() =>
  bookingContactName.value
    ? t('CALENDAR.OPPORTUNITY.BOOK_DESCRIPTION', {
        contact: bookingContactName.value,
      })
    : t('CALENDAR.OPPORTUNITY.BOOK_DESCRIPTION_BLANK')
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
const recurrencePreview = computed(() => {
  if (!recurrenceEnabled.value || !startsAt.value) return [];

  const count = Math.min(Number(occurrenceCount.value) || 1, 10);
  const first = new Date(startsAt.value);
  if (Number.isNaN(first.getTime())) return [];

  return Array.from({ length: count }, (_, index) => {
    const date = new Date(first);
    if (intervalKind.value === 'weekly')
      date.setDate(date.getDate() + index * 7);
    if (intervalKind.value === 'biweekly')
      date.setDate(date.getDate() + index * 14);
    if (intervalKind.value === 'monthly')
      date.setMonth(date.getMonth() + index);
    if (intervalKind.value === 'days') {
      date.setDate(date.getDate() + index * Number(intervalDays.value || 0));
    }
    return date;
  });
});
const recurrenceIntervalLabel = interval =>
  ({
    weekly: t('CALENDAR.OPPORTUNITY.INTERVALS.WEEKLY'),
    biweekly: t('CALENDAR.OPPORTUNITY.INTERVALS.BIWEEKLY'),
    monthly: t('CALENDAR.OPPORTUNITY.INTERVALS.MONTHLY'),
    days: t('CALENDAR.OPPORTUNITY.INTERVALS.DAYS'),
  })[interval] || interval;
const hasAvailabilityConflict = computed(
  () => availabilityResult.value?.available === false
);
const selectedDate = computed(() => startsAt.value.split('T')[0] || '');
const availabilityErrorMessage = computed(() =>
  availabilityResult.value?.conflict
    ? t('CALENDAR.OPPORTUNITY.AVAILABILITY_CONFLICT')
    : t('CALENDAR.OPPORTUNITY.AVAILABILITY_UNAVAILABLE')
);
const canSave = computed(
  () =>
    !!bookingContactId.value &&
    !!procedureId.value &&
    !!resourceId.value &&
    !!startsAt.value &&
    !hasAvailabilityConflict.value &&
    !isCheckingAvailability.value &&
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
  availabilityResult.value = null;
  isCheckingAvailability.value = false;
  availabilitySlots.value = [];
  isLoadingSlots.value = false;
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
  if (!resourceId.value || !startsAt.value || !procedureId.value) {
    availabilityResult.value = null;
    return;
  }

  isCheckingAvailability.value = true;

  try {
    const response = await CalendarAPI.getAvailability({
      starts_at: new Date(startsAt.value).toISOString(),
      procedure_id: Number(procedureId.value),
      resource_id: Number(resourceId.value),
    });
    availabilityResult.value = response.data || null;
  } catch {
    availabilityResult.value = null;
  } finally {
    isCheckingAvailability.value = false;
  }
};

const debouncedCheckAvailability = debounce(checkAvailability, 250, false);

const loadAvailabilitySlots = async () => {
  if (!resourceId.value || !selectedDate.value || !procedureId.value) {
    availabilitySlots.value = [];
    return;
  }

  isLoadingSlots.value = true;
  try {
    const response = await CalendarAPI.getAvailability({
      date: selectedDate.value,
      procedure_id: Number(procedureId.value),
      resource_id: Number(resourceId.value),
    });
    availabilitySlots.value = response.data?.slots || [];
  } catch {
    availabilitySlots.value = [];
  } finally {
    isLoadingSlots.value = false;
  }
};

const debouncedLoadAvailabilitySlots = debounce(
  loadAvailabilitySlots,
  250,
  false
);

const toLocalDateTimeValue = value => {
  const localDate = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(localDate.getTime())) return '';

  const pad = part => String(part).padStart(2, '0');
  return `${localDate.getFullYear()}-${pad(localDate.getMonth() + 1)}-${pad(localDate.getDate())}T${pad(localDate.getHours())}:${pad(localDate.getMinutes())}`;
};

const selectAvailabilitySlot = slot => {
  startsAt.value = toLocalDateTimeValue(slot);
};

const slotLabel = slot =>
  new Intl.DateTimeFormat(undefined, {
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(slot));
const previewDateLabel = date =>
  new Intl.DateTimeFormat(undefined, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(date);

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

const open = async ({ startsAt: initialStartsAt } = {}) => {
  resetForm();
  if (initialStartsAt) {
    startsAt.value = toLocalDateTimeValue(initialStartsAt);
  }
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
    if (saveError?.response?.status === 409) {
      availabilityResult.value = { available: false, conflict: true };
      await loadAvailabilitySlots();
      return;
    }

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

watch([procedureId, resourceId, startsAt], debouncedCheckAvailability);
watch([procedureId, resourceId, selectedDate], debouncedLoadAvailabilitySlots);

onUnmounted(abortContactSearch);

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialog"
    width="md"
    overflow-y-auto
    :title="t('CALENDAR.OPPORTUNITY.BOOK_TITLE')"
    :description="bookingDescription"
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
        <div v-if="selectContact" class="grid gap-2">
          <RaevoField
            :label="t('CALENDAR.OPPORTUNITY.CONTACT')"
            :hint="
              isSearchingContacts
                ? t('CALENDAR.OPPORTUNITY.SEARCHING_CONTACT')
                : ''
            "
          >
            <template #default="{ controlClass, fieldId, describedBy }">
              <input
                :id="fieldId"
                v-model="contactSearchQuery"
                data-testid="calendar-appointment-contact-search"
                type="search"
                :aria-describedby="describedBy"
                :placeholder="t('CALENDAR.OPPORTUNITY.SEARCH_CONTACT')"
                :class="controlClass"
                @input="onContactInput"
              />
            </template>
          </RaevoField>
          <div
            v-if="!isSearchingContacts && contactResults.length"
            class="grid gap-1"
          >
            <button
              v-for="contact in contactResults"
              :key="contact.id"
              type="button"
              class="rounded-lg px-2 py-1.5 text-left text-sm text-n-slate-12 outline-none hover:bg-n-alpha-2 focus:ring-2 focus:ring-n-brand/40"
              @click="selectSearchContact(contact)"
            >
              {{ contact.name || contact.email || contact.phoneNumber }}
            </button>
          </div>
        </div>

        <RaevoField
          :label="t('CALENDAR.OPPORTUNITY.PROCEDURE')"
          variant="select"
        >
          <template #default="{ controlClass, fieldId }">
            <select
              :id="fieldId"
              v-model="procedureId"
              data-testid="kanban-calendar-procedure"
              :class="controlClass"
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
          </template>
        </RaevoField>

        <div
          v-if="selectedProcedure?.recurrence_allowed"
          class="grid gap-3 rounded-md border border-n-weak bg-n-surface-2 p-3 sm:grid-cols-[8rem_minmax(0,1fr)]"
        >
          <RaevoField :label="t('CALENDAR.OPPORTUNITY.SESSIONS')">
            <template #default="{ controlClass, fieldId }">
              <input
                :id="fieldId"
                v-model="occurrenceCount"
                data-testid="kanban-calendar-occurrence-count"
                type="number"
                min="1"
                :max="selectedProcedure.max_sessions || 100"
                :disabled="!selectedProcedure.recurrence_allowed"
                :class="controlClass"
              />
            </template>
          </RaevoField>
          <RaevoField
            v-if="recurrenceEnabled"
            :label="t('CALENDAR.OPPORTUNITY.RECURRENCE')"
            variant="select"
          >
            <template #default="{ controlClass, fieldId }">
              <select
                :id="fieldId"
                v-model="intervalKind"
                data-testid="kanban-calendar-interval-kind"
                :class="controlClass"
              >
                <option
                  v-for="interval in recurrenceIntervals"
                  :key="interval"
                  :value="interval"
                >
                  {{ recurrenceIntervalLabel(interval) }}
                </option>
              </select>
            </template>
          </RaevoField>
          <RaevoField
            v-if="recurrenceEnabled && intervalKind === 'days'"
            class="sm:col-span-2"
            :label="t('CALENDAR.OPPORTUNITY.INTERVAL_DAYS')"
          >
            <template #default="{ controlClass, fieldId }">
              <input
                :id="fieldId"
                v-model="intervalDays"
                data-testid="kanban-calendar-interval-days"
                type="number"
                min="1"
                :class="controlClass"
              />
            </template>
          </RaevoField>
        </div>

        <RaevoField
          :label="t('CALENDAR.OPPORTUNITY.RESOURCE')"
          variant="select"
        >
          <template #default="{ controlClass, fieldId }">
            <select
              :id="fieldId"
              v-model="resourceId"
              data-testid="kanban-calendar-resource"
              :disabled="!procedureId"
              :class="controlClass"
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
          </template>
        </RaevoField>

        <RaevoField :label="t('CALENDAR.OPPORTUNITY.STARTS_AT')">
          <template #default="{ controlClass, fieldId }">
            <input
              :id="fieldId"
              v-model="startsAt"
              data-testid="kanban-calendar-starts-at"
              type="datetime-local"
              :class="controlClass"
            />
          </template>
        </RaevoField>
        <div
          v-if="recurrencePreview.length"
          class="grid gap-1 rounded-md border border-n-weak bg-n-surface-2 p-2.5"
        >
          <span class="text-xs font-medium text-n-slate-12">
            {{ t('CALENDAR.OPPORTUNITY.SERIES_PREVIEW') }}
          </span>
          <ol class="mb-0 grid gap-0.5 text-xs text-n-slate-11">
            <li
              v-for="(date, index) in recurrencePreview"
              :key="date.getTime()"
            >
              {{
                t('CALENDAR.OPPORTUNITY.SERIES_PREVIEW_ITEM', {
                  number: index + 1,
                  date: previewDateLabel(date),
                })
              }}
            </li>
          </ol>
          <span
            v-if="Number(occurrenceCount) > recurrencePreview.length"
            class="text-xs text-n-slate-11"
          >
            {{
              t('CALENDAR.OPPORTUNITY.SERIES_PREVIEW_MORE', {
                count: Number(occurrenceCount) - recurrencePreview.length,
              })
            }}
          </span>
        </div>
        <p v-if="isCheckingAvailability" class="mb-0 text-xs text-n-slate-11">
          {{ t('CALENDAR.OPPORTUNITY.CHECKING_AVAILABILITY') }}
        </p>
        <p
          v-else-if="hasAvailabilityConflict"
          class="mb-0 text-sm text-n-ruby-11"
          role="alert"
        >
          {{ availabilityErrorMessage }}
        </p>
        <div
          v-if="selectedDate && resourceId && procedureId"
          class="grid gap-1.5 rounded-md bg-n-surface-2 p-2.5"
        >
          <div class="flex items-center justify-between gap-2">
            <span class="text-xs font-medium text-n-slate-12">
              {{ t('CALENDAR.OPPORTUNITY.AVAILABLE_TIMES') }}
            </span>
            <span v-if="isLoadingSlots" class="text-xs text-n-slate-11">
              {{ t('CALENDAR.OPPORTUNITY.LOADING_AVAILABLE_TIMES') }}
            </span>
          </div>
          <div v-if="availabilitySlots.length" class="flex flex-wrap gap-1.5">
            <button
              v-for="slot in availabilitySlots"
              :key="slot"
              type="button"
              data-testid="calendar-availability-slot"
              class="rounded border border-n-weak bg-n-surface-1 px-2 py-1 text-xs font-medium text-n-slate-12 outline-none hover:border-n-brand hover:text-n-brand focus:ring-2 focus:ring-n-brand/40"
              @click="selectAvailabilitySlot(slot)"
            >
              {{ slotLabel(slot) }}
            </button>
          </div>
          <p v-else-if="!isLoadingSlots" class="mb-0 text-xs text-n-slate-11">
            {{ t('CALENDAR.OPPORTUNITY.NO_AVAILABLE_TIMES') }}
          </p>
        </div>
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
          data-testid="calendar-confirm-booking"
          :label="t('CALENDAR.OPPORTUNITY.CONFIRM_BOOKING')"
          :disabled="!canSave || isLoading"
          :is-loading="isSaving"
          @click="save"
        />
      </div>
    </template>
  </Dialog>
</template>
