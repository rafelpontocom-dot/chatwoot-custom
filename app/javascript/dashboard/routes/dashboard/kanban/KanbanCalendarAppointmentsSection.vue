<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';

import CalendarAPI from 'dashboard/api/calendar';
import NextButton from 'dashboard/components-next/button/Button.vue';
import KanbanCalendarBookingDialog from './KanbanCalendarBookingDialog.vue';
import CalendarAppointmentDetailsDialog from '../calendar/CalendarAppointmentDetailsDialog.vue';

const props = defineProps({
  cardId: { type: [Number, String], required: true },
  contactId: { type: [Number, String], default: null },
  contactName: { type: String, default: '' },
  allowedProcedureIds: { type: Array, default: () => [] },
  bookingStage: { type: Boolean, default: false },
});

const { t } = useI18n();
const appointments = ref([]);
const isLoading = ref(false);
const error = ref('');
const bookingDialog = ref(null);
const detailsDialog = ref(null);

const sortedAppointments = computed(() =>
  [...appointments.value].sort(
    (firstAppointment, secondAppointment) =>
      new Date(firstAppointment.starts_at) -
      new Date(secondAppointment.starts_at)
  )
);
const formatAppointmentTime = appointment =>
  new Intl.DateTimeFormat(undefined, {
    dateStyle: 'short',
    timeStyle: 'short',
    timeZone: appointment.timezone,
  }).format(new Date(appointment.starts_at));

const loadAppointments = async () => {
  isLoading.value = true;
  error.value = '';

  try {
    const response = await CalendarAPI.getAppointments({
      kanban_card_id: props.cardId,
    });
    appointments.value = response.data || [];
  } catch (loadError) {
    error.value =
      loadError?.response?.data?.message ||
      loadError?.message ||
      t('CALENDAR.OPPORTUNITY.LOAD_ERROR');
  } finally {
    isLoading.value = false;
  }
};

const openBooking = () => bookingDialog.value?.open();
const openDetails = appointment => detailsDialog.value?.open(appointment.id);
const handleCreated = () => loadAppointments();

onMounted(loadAppointments);
</script>

<template>
  <section
    data-testid="kanban-opportunity-calendar-section"
    class="grid gap-3 rounded-lg border border-n-weak p-3"
  >
    <div class="flex items-center justify-between gap-3">
      <div class="flex min-w-0 items-center gap-2">
        <i class="i-lucide-calendar-days size-4 shrink-0 text-n-brand" />
        <h3 class="mb-0 text-sm font-medium text-n-slate-12">
          {{ t('CALENDAR.OPPORTUNITY.TITLE') }}
        </h3>
      </div>
      <NextButton
        type="button"
        xs
        outline
        :disabled="!contactId"
        data-testid="kanban-opportunity-book-appointment"
        icon="i-lucide-plus"
        :label="t('CALENDAR.OPPORTUNITY.BOOK')"
        @click="openBooking"
      />
    </div>

    <p v-if="isLoading" class="mb-0 text-sm text-n-slate-11">
      {{ t('CALENDAR.OPPORTUNITY.LOADING') }}
    </p>
    <p v-else-if="error" class="mb-0 text-sm text-n-ruby-11" role="alert">
      {{ error }}
    </p>
    <p
      v-if="bookingStage && !sortedAppointments.length"
      class="mb-0 rounded-md bg-n-brand/10 px-2.5 py-2 text-xs text-n-brand"
    >
      {{ t('CALENDAR.OPPORTUNITY.BOOKING_STAGE_HINT') }}
    </p>
    <p
      v-else-if="!sortedAppointments.length"
      class="mb-0 text-sm text-n-slate-11"
    >
      {{ t('CALENDAR.OPPORTUNITY.EMPTY') }}
    </p>
    <div v-else class="grid gap-2">
      <button
        v-for="appointment in sortedAppointments"
        :key="appointment.id"
        type="button"
        class="grid gap-0.5 rounded-md bg-n-surface-2 px-2.5 py-2 text-left outline-none transition-colors hover:bg-n-alpha-2 focus:ring-2 focus:ring-n-brand/40"
        @click="openDetails(appointment)"
      >
        <strong class="text-sm text-n-slate-12">
          {{ appointment.procedure.name }}
        </strong>
        <span class="text-xs text-n-slate-11">
          {{ formatAppointmentTime(appointment) }}
          <template v-if="appointment.resources.length">
            {{
              ` · ${appointment.resources.map(resource => resource.name).join(', ')}`
            }}
          </template>
        </span>
      </button>
    </div>

    <KanbanCalendarBookingDialog
      ref="bookingDialog"
      :card-id="cardId"
      :contact-id="contactId"
      :contact-name="contactName"
      :allowed-procedure-ids="allowedProcedureIds"
      @created="handleCreated"
    />
    <CalendarAppointmentDetailsDialog
      ref="detailsDialog"
      @updated="handleCreated"
    />
  </section>
</template>
