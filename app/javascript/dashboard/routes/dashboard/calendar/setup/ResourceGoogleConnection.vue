<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import CalendarAPI from 'dashboard/api/calendar';
import SetupButton from './shared/SetupButton.vue';
import SetupPill from './shared/SetupPill.vue';
import SetupRow from './shared/SetupRow.vue';
import { apiErrorMessage } from './setupHelpers';

// Google Agenda de uma agenda: ligar, sincronizar agora, desligar, e o motivo
// quando o Google recusa — dito em português, com o passo seguinte.
const props = defineProps({
  resourceId: { type: Number, required: true },
});

const emit = defineEmits(['changed']);
const { t } = useI18n();

const connection = ref(null);
const isBusy = ref(false);
const error = ref('');

const GOOGLE_MISSING_PERMISSION = /insufficient authentication scopes/i;
const GOOGLE_API_DISABLED = /has not been used in project|is disabled/i;

const canSync = computed(
  () => connection.value?.connected || connection.value?.retryable
);

const googleError = computed(() => {
  const message = connection.value?.last_error;
  if (!message) return '';
  if (GOOGLE_MISSING_PERMISSION.test(message))
    return t('CALENDAR.SETTINGS.GOOGLE_CALENDAR.MISSING_PERMISSION');
  if (GOOGLE_API_DISABLED.test(message))
    return t('CALENDAR.SETTINGS.GOOGLE_CALENDAR.API_DISABLED');
  return message;
});

const formatTime = value =>
  new Intl.DateTimeFormat(undefined, {
    dateStyle: 'short',
    timeStyle: 'short',
  }).format(new Date(value));

const hint = computed(() => {
  if (!canSync.value) return t('CALENDAR.SETTINGS.GOOGLE_CALENDAR.HELP');
  return connection.value.last_imported_at
    ? t('CALENDAR.SETTINGS.GOOGLE_CALENDAR.LAST_IMPORT', {
        time: formatTime(connection.value.last_imported_at),
      })
    : t('CALENDAR.SETTINGS.GOOGLE_CALENDAR.NEVER_IMPORTED');
});

const load = async () => {
  try {
    const { data } = await CalendarAPI.getGoogleCalendarConnection(
      props.resourceId
    );
    connection.value = data;
  } catch (loadError) {
    error.value = apiErrorMessage(
      loadError,
      t('CALENDAR_SETUP.COMMON.LOAD_ERROR')
    );
  }
};

const run = async action => {
  isBusy.value = true;
  error.value = '';
  try {
    await action();
    emit('changed');
  } catch (actionError) {
    if (actionError?.response?.data?.status)
      connection.value = actionError.response.data;
    else
      error.value = apiErrorMessage(
        actionError,
        t('CALENDAR_SETUP.COMMON.SAVE_ERROR')
      );
  } finally {
    isBusy.value = false;
  }
};

const connect = () =>
  run(async () => {
    const { data } = await CalendarAPI.getGoogleCalendarAuthorizationUrl(
      props.resourceId
    );
    window.location.assign(data.url);
  });

const sync = () =>
  run(async () => {
    const { data } = await CalendarAPI.syncGoogleCalendar(props.resourceId);
    connection.value = data;
  });

const disconnect = () =>
  run(async () => {
    await CalendarAPI.disconnectGoogleCalendar(props.resourceId);
    connection.value = { connected: false, status: 'disconnected' };
  });

onMounted(load);
watch(() => props.resourceId, load);
</script>

<template>
  <div class="grid" data-testid="calendar-setup-google">
    <SetupRow
      :title="t('CALENDAR.SETTINGS.GOOGLE_CALENDAR.TITLE')"
      :hint="hint"
    >
      <SetupPill
        v-if="connection?.connected"
        tone="google"
        :label="t('CALENDAR.SETTINGS.GOOGLE_CALENDAR.CONNECTED')"
      />
      <SetupPill
        v-else-if="connection?.retryable"
        tone="warn"
        :label="t('CALENDAR.SETTINGS.GOOGLE_CALENDAR.STATUS_ERROR')"
      />
      <SetupButton
        v-if="canSync"
        size="sm"
        :label="t('CALENDAR.SETTINGS.GOOGLE_CALENDAR.SYNC_NOW')"
        :loading="isBusy"
        data-testid="calendar-sync-google-calendar"
        @click="sync"
      />
      <SetupButton
        v-if="!connection?.connected"
        size="sm"
        :label="t('CALENDAR.SETTINGS.GOOGLE_CALENDAR.CONNECT')"
        :disabled="isBusy"
        @click="connect"
      />
      <SetupButton
        v-else
        size="sm"
        :label="t('CALENDAR.SETTINGS.GOOGLE_CALENDAR.DISCONNECT')"
        :disabled="isBusy"
        @click="disconnect"
      />
    </SetupRow>
    <p
      v-if="googleError || error"
      class="mb-0 flex items-start gap-1.5 text-xs text-n-ruby-11"
      role="alert"
      data-testid="calendar-google-error"
    >
      <i
        class="i-lucide-triangle-alert mt-0.5 size-3.5 shrink-0"
        aria-hidden="true"
      />
      {{ googleError || error }}
    </p>
  </div>
</template>
