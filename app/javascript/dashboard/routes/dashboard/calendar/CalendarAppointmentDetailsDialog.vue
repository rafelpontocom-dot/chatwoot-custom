<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';

import CalendarAPI from 'dashboard/api/calendar';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const emit = defineEmits(['updated']);

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const dialog = ref(null);
const appointment = ref(null);
const cancellationReason = ref('');
const cancellationScope = ref('this_occurrence');
const isLoading = ref(false);
const isSaving = ref(false);
const error = ref('');
const isRescheduling = ref(false);
const rescheduleStartsAt = ref('');
const rescheduleResourceId = ref('');
const rescheduleScope = ref('this_occurrence');
const resources = ref([]);
const rescheduleAvailabilitySlots = ref([]);
const isLoadingRescheduleSlots = ref(false);

const isActive = computed(() =>
  ['scheduled', 'confirmed', 'checked_in'].includes(appointment.value?.status)
);
const rescheduleSelectedDate = computed(
  () => rescheduleStartsAt.value.split('T')[0] || ''
);
const formatDateTime = value =>
  new Intl.DateTimeFormat(undefined, {
    dateStyle: 'full',
    timeStyle: 'short',
    timeZone: appointment.value?.timezone,
  }).format(new Date(value));
const statusLabel = status =>
  ({
    scheduled: t('CALENDAR.DETAIL.STATUS.SCHEDULED'),
    confirmed: t('CALENDAR.DETAIL.STATUS.CONFIRMED'),
    checked_in: t('CALENDAR.DETAIL.STATUS.CHECKED_IN'),
    completed: t('CALENDAR.DETAIL.STATUS.COMPLETED'),
    no_show: t('CALENDAR.DETAIL.STATUS.NO_SHOW'),
    canceled: t('CALENDAR.DETAIL.STATUS.CANCELED'),
  })[status] || status;
const eventLabel = eventType =>
  ({
    created: t('CALENDAR.DETAIL.EVENTS.CREATED'),
    confirmed: t('CALENDAR.DETAIL.EVENTS.CONFIRMED'),
    checked_in: t('CALENDAR.DETAIL.EVENTS.CHECKED_IN'),
    rescheduled: t('CALENDAR.DETAIL.EVENTS.RESCHEDULED'),
    canceled: t('CALENDAR.DETAIL.EVENTS.CANCELED'),
    completed: t('CALENDAR.DETAIL.EVENTS.COMPLETED'),
    no_show: t('CALENDAR.DETAIL.EVENTS.NO_SHOW'),
  })[eventType] || eventType;
const formatDateTimeInput = value => {
  const date = new Date(value);
  const offset = date.getTimezoneOffset();
  return new Date(date.getTime() - offset * 60000).toISOString().slice(0, 16);
};

const getErrorMessage = errorResponse =>
  errorResponse?.response?.data?.message ||
  errorResponse?.message ||
  t('CALENDAR.DETAIL.SAVE_ERROR');

const open = async appointmentId => {
  appointment.value = null;
  cancellationReason.value = '';
  cancellationScope.value = 'this_occurrence';
  isRescheduling.value = false;
  rescheduleStartsAt.value = '';
  rescheduleResourceId.value = '';
  rescheduleScope.value = 'this_occurrence';
  rescheduleAvailabilitySlots.value = [];
  isLoadingRescheduleSlots.value = false;
  error.value = '';
  dialog.value?.open();
  isLoading.value = true;

  try {
    const response = await CalendarAPI.getAppointment(appointmentId);
    appointment.value = response.data;
    rescheduleStartsAt.value = formatDateTimeInput(appointment.value.starts_at);
    rescheduleResourceId.value = String(
      appointment.value.resources[0]?.id || ''
    );
  } catch (loadError) {
    error.value = getErrorMessage(loadError);
  } finally {
    isLoading.value = false;
  }
};

const openReschedule = async () => {
  if (!appointment.value) return;

  isRescheduling.value = true;
  error.value = '';
  try {
    const response = await CalendarAPI.getResources();
    resources.value = (response.data || []).filter(resource => resource.active);
  } catch (loadError) {
    error.value = getErrorMessage(loadError);
  }
};

const openForReschedule = async (appointmentId, startsAt) => {
  await open(appointmentId);
  await openReschedule();
  rescheduleStartsAt.value = formatDateTimeInput(startsAt);
};

async function loadRescheduleAvailabilitySlots() {
  if (
    !isRescheduling.value ||
    !appointment.value?.procedure?.id ||
    !rescheduleResourceId.value ||
    !rescheduleSelectedDate.value
  ) {
    rescheduleAvailabilitySlots.value = [];
    return;
  }

  isLoadingRescheduleSlots.value = true;
  try {
    const response = await CalendarAPI.getAvailability({
      date: rescheduleSelectedDate.value,
      procedure_id: Number(appointment.value.procedure.id),
      resource_id: Number(rescheduleResourceId.value),
    });
    rescheduleAvailabilitySlots.value = response.data?.slots || [];
  } catch {
    rescheduleAvailabilitySlots.value = [];
  } finally {
    isLoadingRescheduleSlots.value = false;
  }
}

function selectRescheduleSlot(slot) {
  rescheduleStartsAt.value = formatDateTimeInput(slot);
}

const formatSlot = slot =>
  new Intl.DateTimeFormat(undefined, {
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(slot));

watch(
  [isRescheduling, rescheduleResourceId, rescheduleSelectedDate],
  loadRescheduleAvailabilitySlots
);

const saveReschedule = async () => {
  if (
    !appointment.value ||
    !rescheduleStartsAt.value ||
    !rescheduleResourceId.value
  )
    return;

  isSaving.value = true;
  error.value = '';
  try {
    const response = await CalendarAPI.rescheduleAppointment(
      appointment.value.id,
      {
        appointment: {
          starts_at: new Date(rescheduleStartsAt.value).toISOString(),
          resource_ids: [Number(rescheduleResourceId.value)],
          scope: rescheduleScope.value,
          lock_version: appointment.value.lock_version,
        },
      }
    );
    appointment.value = response.data;
    isRescheduling.value = false;
    emit('updated', response.data);
  } catch (saveError) {
    error.value = getErrorMessage(saveError);
  } finally {
    isSaving.value = false;
  }
};

const close = () => dialog.value?.close();
const reloadAppointment = () => open(appointment.value?.id);

const openOpportunity = () => {
  const card = appointment.value?.kanban_card;
  if (!card?.kanban_board_id) return;

  close();
  router.push({
    name: 'kanban_board_show',
    params: {
      accountId: route.params.accountId,
      boardId: card.kanban_board_id,
    },
    query: { cardId: card.id },
  });
};

const changeStatus = async action => {
  if (!appointment.value || isSaving.value) return;
  if (action === 'cancel' && !cancellationReason.value.trim()) {
    error.value = t('CALENDAR.DETAIL.CANCELLATION_REASON_REQUIRED');
    return;
  }

  isSaving.value = true;
  error.value = '';
  try {
    const response = await CalendarAPI.updateAppointment(appointment.value.id, {
      appointment: {
        action,
        lock_version: appointment.value.lock_version,
        cancellation_reason:
          action === 'cancel' ? cancellationReason.value.trim() : undefined,
        scope: action === 'cancel' ? cancellationScope.value : undefined,
      },
    });
    appointment.value = response.data;
    emit('updated', response.data);
  } catch (saveError) {
    error.value = getErrorMessage(saveError);
  } finally {
    isSaving.value = false;
  }
};

defineExpose({ open, openForReschedule });
</script>

<template>
  <Dialog
    ref="dialog"
    width="md"
    overflow-y-auto
    :title="t('CALENDAR.DETAIL.TITLE')"
    :show-confirm-button="false"
    @close="appointment = null"
  >
    <p v-if="isLoading" class="mb-0 text-sm text-n-slate-11">
      {{ t('CALENDAR.DETAIL.LOADING') }}
    </p>
    <p
      v-else-if="error && !appointment"
      class="mb-0 text-sm text-n-ruby-11"
      role="alert"
    >
      {{ error }}
    </p>
    <template v-else-if="appointment">
      <div class="grid gap-3">
        <div class="grid gap-1 rounded-lg bg-n-surface-2 p-3">
          <strong class="text-base text-n-slate-12">{{
            appointment.procedure.name
          }}</strong>
          <span class="text-sm text-n-slate-11">{{
            appointment.contact.name
          }}</span>
          <NextButton
            v-if="appointment.kanban_card"
            type="button"
            sm
            outline
            icon="i-lucide-arrow-up-right"
            :label="t('CALENDAR.DETAIL.OPEN_OPPORTUNITY')"
            class="mt-2 justify-self-start"
            @click="openOpportunity"
          />
        </div>
        <dl class="grid gap-3 text-sm">
          <div class="grid gap-1">
            <dt class="text-n-slate-10">
              {{ t('CALENDAR.DETAIL.DATE_TIME') }}
            </dt>
            <dd class="m-0 text-n-slate-12">
              {{ formatDateTime(appointment.starts_at) }}
            </dd>
          </div>
          <div class="grid gap-1">
            <dt class="text-n-slate-10">{{ t('CALENDAR.DETAIL.RESOURCE') }}</dt>
            <dd class="m-0 text-n-slate-12">
              {{
                appointment.resources.map(resource => resource.name).join(', ')
              }}
            </dd>
          </div>
          <div class="grid gap-1">
            <dt class="text-n-slate-10">
              {{ t('CALENDAR.DETAIL.STATUS_LABEL') }}
            </dt>
            <dd class="m-0 text-n-slate-12">
              {{ statusLabel(appointment.status) }}
            </dd>
          </div>
          <div v-if="appointment.series?.planned_count > 1" class="grid gap-1">
            <dt class="text-n-slate-10">
              {{ t('CALENDAR.DETAIL.SERIES_LABEL') }}
            </dt>
            <dd class="m-0 text-n-slate-12">
              {{
                t('CALENDAR.DETAIL.SERIES_VALUE', {
                  current: appointment.occurrence_number,
                  total: appointment.series.planned_count,
                })
              }}
            </dd>
          </div>
        </dl>
        <section
          v-if="appointment.events?.length"
          class="grid gap-2 border-t border-n-weak pt-3"
        >
          <h3 class="mb-0 text-sm font-medium text-n-slate-12">
            {{ t('CALENDAR.DETAIL.EVENTS.TITLE') }}
          </h3>
          <ol class="m-0 grid list-none gap-1.5 p-0">
            <li
              v-for="event in appointment.events"
              :key="event.id"
              class="flex items-center justify-between gap-3 text-sm"
            >
              <span class="text-n-slate-12">{{
                eventLabel(event.event_type)
              }}</span>
              <time class="shrink-0 text-xs text-n-slate-11">
                {{ formatDateTime(event.occurred_at) }}
              </time>
            </li>
          </ol>
        </section>
        <label v-if="isActive" class="grid gap-1.5">
          <span class="text-sm font-medium text-n-slate-12">{{
            t('CALENDAR.DETAIL.CANCELLATION_REASON')
          }}</span>
          <input
            v-model="cancellationReason"
            type="text"
            class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
          />
        </label>
        <label v-if="isActive" class="grid gap-1.5">
          <span class="text-sm font-medium text-n-slate-12">{{
            t('CALENDAR.DETAIL.CANCELLATION_SCOPE')
          }}</span>
          <select
            v-model="cancellationScope"
            class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
          >
            <option value="this_occurrence">
              {{ t('CALENDAR.DETAIL.CANCELLATION_SCOPES.THIS_OCCURRENCE') }}
            </option>
            <option value="this_and_future">
              {{ t('CALENDAR.DETAIL.CANCELLATION_SCOPES.THIS_AND_FUTURE') }}
            </option>
            <option value="all_occurrences">
              {{ t('CALENDAR.DETAIL.CANCELLATION_SCOPES.ALL_OCCURRENCES') }}
            </option>
          </select>
        </label>
        <div
          v-if="isRescheduling"
          class="grid gap-3 rounded-lg border border-n-weak bg-n-surface-2 p-3"
        >
          <label class="grid gap-1.5">
            <span class="text-sm font-medium text-n-slate-12">{{
              t('CALENDAR.DETAIL.NEW_DATE_TIME')
            }}</span>
            <input
              v-model="rescheduleStartsAt"
              type="datetime-local"
              class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
            />
          </label>
          <label class="grid gap-1.5">
            <span class="text-sm font-medium text-n-slate-12">{{
              t('CALENDAR.DETAIL.RESCHEDULE_SCOPE')
            }}</span>
            <select
              v-model="rescheduleScope"
              class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
            >
              <option value="this_occurrence">
                {{ t('CALENDAR.DETAIL.RESCHEDULE_SCOPES.THIS_OCCURRENCE') }}
              </option>
              <option value="this_and_future">
                {{ t('CALENDAR.DETAIL.RESCHEDULE_SCOPES.THIS_AND_FUTURE') }}
              </option>
              <option value="all_occurrences">
                {{ t('CALENDAR.DETAIL.RESCHEDULE_SCOPES.ALL_OCCURRENCES') }}
              </option>
            </select>
          </label>
          <label class="grid gap-1.5">
            <span class="text-sm font-medium text-n-slate-12">{{
              t('CALENDAR.DETAIL.RESOURCE')
            }}</span>
            <select
              v-model="rescheduleResourceId"
              class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
            >
              <option
                v-for="resource in resources"
                :key="resource.id"
                :value="String(resource.id)"
              >
                {{ resource.name }}
              </option>
            </select>
          </label>
          <div class="grid gap-1.5">
            <span class="text-sm font-medium text-n-slate-12">{{
              t('CALENDAR.DETAIL.AVAILABLE_TIMES')
            }}</span>
            <p
              v-if="isLoadingRescheduleSlots"
              class="mb-0 text-sm text-n-slate-11"
            >
              {{ t('CALENDAR.DETAIL.LOADING_AVAILABLE_TIMES') }}
            </p>
            <p
              v-else-if="rescheduleAvailabilitySlots.length === 0"
              class="mb-0 text-sm text-n-slate-11"
            >
              {{ t('CALENDAR.DETAIL.NO_AVAILABLE_TIMES') }}
            </p>
            <div v-else class="flex flex-wrap gap-1.5">
              <button
                v-for="slot in rescheduleAvailabilitySlots"
                :key="slot"
                type="button"
                data-testid="reschedule-available-slot"
                class="rounded-md border border-n-weak bg-n-surface-1 px-2.5 py-1.5 text-sm text-n-slate-12 outline-none hover:border-n-brand hover:bg-n-brand/10 focus-visible:ring-2 focus-visible:ring-n-brand"
                @click="selectRescheduleSlot(slot)"
              >
                {{ formatSlot(slot) }}
              </button>
            </div>
          </div>
        </div>
        <div
          v-if="error"
          class="flex items-center justify-between gap-2"
          role="alert"
        >
          <p class="mb-0 text-sm text-n-ruby-11">{{ error }}</p>
          <NextButton
            type="button"
            outline
            size="sm"
            :label="t('CALENDAR.DETAIL.RELOAD')"
            :disabled="isSaving"
            @click="reloadAppointment"
          />
        </div>
      </div>
    </template>
    <template #footer>
      <div class="flex flex-wrap justify-end gap-2">
        <NextButton
          type="button"
          link
          slate
          :label="t('GENERAL.CLOSE')"
          @click="close"
        />
        <NextButton
          v-if="isActive && appointment.status === 'scheduled'"
          type="button"
          outline
          size="sm"
          :label="t('CALENDAR.DETAIL.CONFIRM')"
          :disabled="isSaving"
          @click="changeStatus('confirm')"
        />
        <NextButton
          v-if="isActive && appointment.status === 'confirmed'"
          type="button"
          outline
          size="sm"
          :label="t('CALENDAR.DETAIL.CHECK_IN')"
          :disabled="isSaving"
          @click="changeStatus('check_in')"
        />
        <NextButton
          v-if="isActive && !isRescheduling"
          type="button"
          outline
          size="sm"
          :label="t('CALENDAR.DETAIL.RESCHEDULE')"
          :disabled="isSaving"
          @click="openReschedule"
        />
        <NextButton
          v-if="isActive && isRescheduling"
          type="button"
          size="sm"
          :label="t('CALENDAR.DETAIL.SAVE_RESCHEDULE')"
          :disabled="isSaving"
          @click="saveReschedule"
        />
        <NextButton
          v-if="isActive"
          type="button"
          outline
          emerald
          size="sm"
          :label="t('CALENDAR.DETAIL.COMPLETE')"
          :disabled="isSaving"
          @click="changeStatus('complete')"
        />
        <NextButton
          v-if="isActive"
          type="button"
          outline
          amber
          size="sm"
          :label="t('CALENDAR.DETAIL.NO_SHOW')"
          :disabled="isSaving"
          @click="changeStatus('no_show')"
        />
        <NextButton
          v-if="isActive"
          type="button"
          ruby
          size="sm"
          :label="t('CALENDAR.DETAIL.CANCEL')"
          :disabled="isSaving"
          @click="changeStatus('cancel')"
        />
      </div>
    </template>
  </Dialog>
</template>
