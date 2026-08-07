<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { debounce } from '@chatwoot/utils';
import calendarAPI from 'dashboard/api/calendar';
import KanbanCalendarBookingDialog from '../kanban/KanbanCalendarBookingDialog.vue';
import CalendarAppointmentDetailsDialog from './CalendarAppointmentDetailsDialog.vue';
import CalendarSettingsDialog from './CalendarSettingsDialog.vue';

const { t, locale } = useI18n();
const selectedDate = ref(new Date());
const view = ref('week');
const appointments = ref([]);
const resources = ref([]);
const selectedResourceId = ref('');
const searchQuery = ref('');
const isLoading = ref(false);
const loadError = ref(false);
const bookingDialog = ref(null);
const settingsDialog = ref(null);
const appointmentDetailsDialog = ref(null);
const draggedAppointment = ref(null);

const dateFormatter = computed(
  () =>
    new Intl.DateTimeFormat(locale.value === 'pt_BR' ? 'pt-BR' : locale.value, {
      weekday: view.value === 'week' ? 'long' : undefined,
      day: 'numeric',
      month: 'long',
      year: 'numeric',
    })
);

const dateLabel = computed(() =>
  dateFormatter.value.format(selectedDate.value)
);

const firstVisibleDate = computed(() => {
  const date = new Date(selectedDate.value);
  const weekday = date.getDay();
  date.setDate(date.getDate() - (weekday === 0 ? 6 : weekday - 1));
  date.setHours(0, 0, 0, 0);
  return date;
});

const calendarDays = computed(() => {
  const count = view.value === 'day' ? 1 : 7;
  return Array.from({ length: count }, (_, index) => {
    const date = new Date(
      view.value === 'day' ? selectedDate.value : firstVisibleDate.value
    );
    date.setDate(date.getDate() + index);
    date.setHours(0, 0, 0, 0);
    return date;
  });
});

const hourSlots = computed(() => {
  const appointmentHours = appointments.value.map(appointment =>
    new Date(appointment.starts_at).getHours()
  );
  const firstHour = Math.min(8, ...appointmentHours);
  const lastHour = Math.max(17, ...appointmentHours);

  return Array.from(
    { length: lastHour - firstHour + 1 },
    (_, index) => firstHour + index
  );
});
const gridClass = computed(() =>
  view.value === 'day'
    ? 'grid-cols-[4rem_minmax(16rem,1fr)]'
    : 'grid-cols-[4rem_repeat(7,minmax(10rem,1fr))]'
);

const isoDate = date => date.toISOString();

const loadAppointments = async () => {
  isLoading.value = true;
  loadError.value = false;
  const rangeStart = calendarDays.value[0];
  const rangeEnd = new Date(calendarDays.value.at(-1));
  rangeEnd.setDate(rangeEnd.getDate() + 1);

  try {
    const { data } = await calendarAPI.getAppointments({
      starts_at: isoDate(rangeStart),
      ends_at: isoDate(rangeEnd),
      resource_ids: selectedResourceId.value
        ? [Number(selectedResourceId.value)]
        : undefined,
      q: searchQuery.value.trim() || undefined,
    });
    appointments.value = data;
  } catch {
    appointments.value = [];
    loadError.value = true;
  } finally {
    isLoading.value = false;
  }
};

const loadResources = async () => {
  try {
    const response = await calendarAPI.getResources();
    resources.value = (response.data || []).filter(resource => resource.active);
  } catch {
    resources.value = [];
  }
};

const appointmentsForSlot = (day, hour) =>
  appointments.value.filter(appointment => {
    const startsAt = new Date(appointment.starts_at);
    return (
      startsAt.getFullYear() === day.getFullYear() &&
      startsAt.getMonth() === day.getMonth() &&
      startsAt.getDate() === day.getDate() &&
      startsAt.getHours() === hour
    );
  });

const formatDay = day =>
  new Intl.DateTimeFormat(locale.value === 'pt_BR' ? 'pt-BR' : locale.value, {
    weekday: 'short',
    day: 'numeric',
  }).format(day);

const formatTime = value =>
  new Intl.DateTimeFormat(locale.value === 'pt_BR' ? 'pt-BR' : locale.value, {
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value));

const statusLabel = status =>
  ({
    scheduled: t('CALENDAR.DETAIL.STATUS.SCHEDULED'),
    confirmed: t('CALENDAR.DETAIL.STATUS.CONFIRMED'),
    completed: t('CALENDAR.DETAIL.STATUS.COMPLETED'),
    no_show: t('CALENDAR.DETAIL.STATUS.NO_SHOW'),
    canceled: t('CALENDAR.DETAIL.STATUS.CANCELED'),
  })[status] || status;

const changeDay = amount => {
  const nextDate = new Date(selectedDate.value);
  nextDate.setDate(nextDate.getDate() + amount);
  selectedDate.value = nextDate;
};

const goToToday = () => {
  selectedDate.value = new Date();
};

const openBooking = () => bookingDialog.value?.open();
const openSettings = () => settingsDialog.value?.open();
const openAppointment = appointment =>
  appointmentDetailsDialog.value?.open(appointment.id);
const beginRescheduleDrag = appointment => {
  draggedAppointment.value = appointment;
};
const assistedReschedule = (day, hour) => {
  if (!draggedAppointment.value) return;

  const startsAt = new Date(day);
  const originalStart = new Date(draggedAppointment.value.starts_at);
  startsAt.setHours(hour, originalStart.getMinutes(), 0, 0);
  appointmentDetailsDialog.value?.openForReschedule(
    draggedAppointment.value.id,
    startsAt.toISOString()
  );
  draggedAppointment.value = null;
};
const handleAppointmentCreated = () => loadAppointments();

const debouncedLoadAppointments = debounce(loadAppointments, 250, false);

watch([selectedDate, view, selectedResourceId], loadAppointments);
watch(searchQuery, debouncedLoadAppointments);
onMounted(() => {
  loadAppointments();
  loadResources();
});
</script>

<template>
  <main
    data-testid="calendar-workspace"
    class="flex h-full min-h-0 flex-col bg-n-background px-4 py-4 lg:px-6"
  >
    <header
      class="mb-4 flex flex-col gap-3 border-b border-n-weak pb-4 lg:flex-row lg:items-center lg:justify-between"
    >
      <div class="flex min-w-0 items-center gap-2">
        <div
          class="flex size-9 flex-none items-center justify-center rounded-md bg-n-brand/10 text-n-brand"
        >
          <i class="i-lucide-calendar-days size-5" aria-hidden="true" />
        </div>
        <div class="min-w-0">
          <h1 class="mb-0 truncate text-lg font-semibold text-n-slate-12">
            {{ t('CALENDAR.TITLE') }}
          </h1>
          <p class="mb-0 text-sm text-n-slate-11">{{ dateLabel }}</p>
        </div>
      </div>

      <div class="flex flex-wrap items-center gap-2">
        <label class="sr-only" for="calendar-resource-filter">
          {{ t('CALENDAR.RESOURCE_FILTER') }}
        </label>
        <select
          id="calendar-resource-filter"
          v-model="selectedResourceId"
          class="h-9 max-w-48 rounded-md border border-n-weak bg-n-surface-1 px-2 text-sm text-n-slate-12 outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
        >
          <option value="">{{ t('CALENDAR.ALL_RESOURCES') }}</option>
          <option
            v-for="resource in resources"
            :key="resource.id"
            :value="String(resource.id)"
          >
            {{ resource.name }}
          </option>
        </select>
        <label class="sr-only" for="calendar-search">
          {{ t('CALENDAR.SEARCH') }}
        </label>
        <input
          id="calendar-search"
          v-model="searchQuery"
          type="search"
          :placeholder="t('CALENDAR.SEARCH_PLACEHOLDER')"
          class="h-9 w-56 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none placeholder:text-n-slate-10 focus-visible:ring-2 focus-visible:ring-n-brand"
        />
        <button
          type="button"
          data-testid="calendar-open-settings"
          class="flex size-9 items-center justify-center rounded-md border border-n-weak text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus-visible:ring-2 focus-visible:ring-n-brand"
          :aria-label="t('CALENDAR.SETTINGS.OPEN')"
          :title="t('CALENDAR.SETTINGS.OPEN')"
          @click="openSettings"
        >
          <i class="i-lucide-settings-2 size-4" aria-hidden="true" />
        </button>
        <div
          class="inline-flex rounded-md border border-n-weak bg-n-solid-1 p-0.5"
          role="group"
        >
          <button
            type="button"
            class="flex size-8 items-center justify-center rounded text-n-slate-11 outline-none hover:bg-n-alpha-2 focus-visible:ring-2 focus-visible:ring-n-brand"
            :aria-label="t('CALENDAR.PREVIOUS')"
            :title="t('CALENDAR.PREVIOUS')"
            @click="changeDay(view === 'week' ? -7 : -1)"
          >
            <i class="i-lucide-chevron-left size-4" aria-hidden="true" />
          </button>
          <button
            type="button"
            class="px-2 text-sm font-medium text-n-slate-12 outline-none hover:bg-n-alpha-2 focus-visible:ring-2 focus-visible:ring-n-brand"
            @click="goToToday"
          >
            {{ t('CALENDAR.TODAY') }}
          </button>
          <button
            type="button"
            class="flex size-8 items-center justify-center rounded text-n-slate-11 outline-none hover:bg-n-alpha-2 focus-visible:ring-2 focus-visible:ring-n-brand"
            :aria-label="t('CALENDAR.NEXT')"
            :title="t('CALENDAR.NEXT')"
            @click="changeDay(view === 'week' ? 7 : 1)"
          >
            <i class="i-lucide-chevron-right size-4" aria-hidden="true" />
          </button>
        </div>

        <div
          class="inline-flex rounded-md border border-n-weak bg-n-solid-1 p-0.5"
          role="group"
        >
          <button
            type="button"
            class="rounded px-2.5 py-1.5 text-sm outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
            :class="
              view === 'day'
                ? 'bg-n-brand text-white'
                : 'text-n-slate-11 hover:bg-n-alpha-2'
            "
            @click="view = 'day'"
          >
            {{ t('CALENDAR.DAY') }}
          </button>
          <button
            type="button"
            class="rounded px-2.5 py-1.5 text-sm outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
            :class="
              view === 'week'
                ? 'bg-n-brand text-white'
                : 'text-n-slate-11 hover:bg-n-alpha-2'
            "
            @click="view = 'week'"
          >
            {{ t('CALENDAR.WEEK') }}
          </button>
        </div>

        <button
          type="button"
          data-testid="calendar-new-appointment"
          class="inline-flex items-center gap-2 rounded-md bg-n-brand px-3 py-2 text-sm font-medium text-white outline-none hover:bg-n-brand/90 focus-visible:ring-2 focus-visible:ring-n-brand focus-visible:ring-offset-2"
          @click="openBooking"
        >
          <i class="i-lucide-plus size-4" aria-hidden="true" />
          {{ t('CALENDAR.NEW_APPOINTMENT') }}
        </button>
      </div>
    </header>

    <section
      class="relative flex min-h-0 flex-1 overflow-hidden rounded-lg border border-n-weak bg-n-solid-1"
      :aria-label="t('CALENDAR.GRID_LABEL')"
    >
      <div class="grid w-full overflow-auto" :class="gridClass">
        <div
          class="sticky left-0 z-10 border-b border-r border-n-weak bg-n-solid-1"
        />
        <div
          v-for="day in calendarDays"
          :key="day.toISOString()"
          data-testid="calendar-day-column"
          class="min-h-14 border-b border-r border-n-weak bg-n-solid-1 px-3 py-2 last:border-r-0"
        >
          <span class="text-xs font-medium text-n-slate-11">
            {{ formatDay(day) }}
          </span>
        </div>
        <template v-for="hour in hourSlots" :key="hour">
          <div
            class="sticky left-0 z-10 border-b border-r border-n-weak bg-n-solid-1 px-2 py-2 text-right text-xs text-n-slate-11"
          >
            {{ `${hour}:00` }}
          </div>
          <div
            v-for="day in calendarDays"
            :key="`${hour}-${day.toISOString()}`"
            class="min-h-20 border-b border-r border-n-weak bg-n-solid-1 p-1 last:border-r-0"
            @dragover.prevent
            @drop="assistedReschedule(day, hour)"
          >
            <button
              v-for="appointment in appointmentsForSlot(day, hour)"
              :key="appointment.id"
              type="button"
              data-testid="calendar-appointment"
              draggable="true"
              class="mb-1 w-full rounded-md border border-n-brand/30 bg-n-brand/10 px-2 py-1 text-left outline-none hover:bg-n-brand/20 focus-visible:ring-2 focus-visible:ring-n-brand"
              :aria-label="
                t('CALENDAR.APPOINTMENT_LABEL', {
                  time: formatTime(appointment.starts_at),
                  contact: appointment.contact.name,
                  procedure: appointment.procedure.name,
                })
              "
              @click="openAppointment(appointment)"
              @dragstart="beginRescheduleDrag(appointment)"
              @dragend="draggedAppointment = null"
            >
              <span
                class="block truncate text-xs font-semibold text-n-slate-12"
              >
                {{
                  t('CALENDAR.APPOINTMENT_CARD_TITLE', {
                    time: formatTime(appointment.starts_at),
                    contact: appointment.contact.name,
                  })
                }}
              </span>
              <span class="block truncate text-xs text-n-slate-11">
                {{ appointment.procedure.name }}
              </span>
              <span
                v-if="appointment.resources?.length"
                data-testid="calendar-appointment-resource"
                class="block truncate text-xs text-n-slate-11"
              >
                {{
                  appointment.resources
                    .map(resource => resource.name)
                    .join(', ')
                }}
              </span>
              <span
                data-testid="calendar-appointment-status"
                class="block truncate text-xs font-medium text-n-slate-12"
              >
                {{ statusLabel(appointment.status) }}
              </span>
            </button>
          </div>
        </template>
      </div>

      <div
        v-if="isLoading"
        class="pointer-events-none absolute inset-0 flex items-center justify-center bg-n-solid-1/80"
      >
        <p class="text-sm text-n-slate-11">{{ t('CALENDAR.LOADING') }}</p>
      </div>
      <div
        v-else-if="loadError"
        class="absolute inset-0 flex items-center justify-center"
      >
        <div
          class="max-w-sm rounded-md border border-n-weak bg-n-solid-1 px-5 py-4 text-center shadow-sm"
        >
          <p class="mb-1 text-sm font-medium text-n-slate-12">
            {{ t('CALENDAR.LOAD_ERROR_TITLE') }}
          </p>
          <button
            type="button"
            class="text-sm font-medium text-n-brand outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
            @click="loadAppointments"
          >
            {{ t('CALENDAR.RETRY') }}
          </button>
        </div>
      </div>
      <div
        v-else-if="appointments.length === 0"
        class="pointer-events-none absolute inset-0 flex items-center justify-center"
      >
        <div
          class="max-w-sm rounded-md border border-n-weak bg-n-solid-1 px-5 py-4 text-center shadow-sm"
        >
          <i
            class="i-lucide-calendar-plus mx-auto mb-2 size-5 text-n-brand"
            aria-hidden="true"
          />
          <p class="mb-1 text-sm font-medium text-n-slate-12">
            {{ t('CALENDAR.EMPTY_TITLE') }}
          </p>
          <p class="mb-0 text-sm text-n-slate-11">
            {{ t('CALENDAR.EMPTY_DESCRIPTION') }}
          </p>
        </div>
      </div>
    </section>

    <KanbanCalendarBookingDialog
      ref="bookingDialog"
      select-contact
      @created="handleAppointmentCreated"
    />
    <CalendarSettingsDialog ref="settingsDialog" />
    <CalendarAppointmentDetailsDialog
      ref="appointmentDetailsDialog"
      @updated="loadAppointments"
    />
  </main>
</template>
