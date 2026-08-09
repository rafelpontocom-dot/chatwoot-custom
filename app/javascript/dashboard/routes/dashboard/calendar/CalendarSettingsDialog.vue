<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { copyTextToClipboard } from 'shared/helpers/clipboard';

import CalendarAPI from 'dashboard/api/calendar';
import NextButton from 'dashboard/components-next/button/Button.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const emit = defineEmits(['updated']);

const { t } = useI18n();
const store = useStore();
const agents = useMapGetter('agents/getAgents');
const boards = useMapGetter('kanbanBoards/kanbanBoards');
const inboxes = useMapGetter('inboxes/getAllInboxes');
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
const editingProcedureId = ref(null);
const editingResourceId = ref(null);
const isProcedureEditorOpen = ref(false);
const isResourceEditorOpen = ref(false);
const bookingPage = ref(null);
const bookingLinks = ref([]);
const googleCalendarConnection = ref(null);
const isLoadingGoogleCalendarConnection = ref(false);
const bookingLinkForm = ref({ procedureId: '', expiresAt: '', maxUses: '' });
const bookingPageForm = ref({
  active: false,
  title: '',
  description: '',
  duplicatePolicy: 'create_new',
  minimumNoticeMinutes: '1440',
  maximumNoticeDays: '60',
  slotIntervalMinutes: '15',
  boardId: '',
  stageId: '',
  inboxId: '',
  captchaProvider: '',
  captchaSiteKey: '',
  publicFormFields: [],
});
const procedureForm = ref({
  name: '',
  durationMinutes: '50',
  bufferBeforeMinutes: '0',
  bufferAfterMinutes: '0',
  locationType: 'in_person',
  color: '#00B8C6',
  recurrenceAllowed: false,
  maxSessions: '10',
  resourceIds: [],
  publicBookingEnabled: false,
  publicTitle: '',
  publicDescription: '',
  publicSlug: '',
});
const resourceForm = ref({ name: '', resourceType: 'generic', userId: '' });
const availabilityForm = ref({
  weekday: '1',
  startsAtLocal: '09:00',
  endsAtLocal: '18:00',
});
const exceptionForm = ref({
  kind: 'block',
  date: '',
  startsAtLocal: '',
  endsAtLocal: '',
});

const canCreateProcedure = computed(
  () =>
    procedureForm.value.name.trim() &&
    Number(procedureForm.value.durationMinutes) > 0 &&
    Number(procedureForm.value.bufferBeforeMinutes) >= 0 &&
    Number(procedureForm.value.bufferAfterMinutes) >= 0 &&
    (!procedureForm.value.publicBookingEnabled ||
      procedureForm.value.publicSlug.trim()) &&
    (!procedureForm.value.recurrenceAllowed ||
      (Number.isInteger(Number(procedureForm.value.maxSessions)) &&
        Number(procedureForm.value.maxSessions) >= 1 &&
        Number(procedureForm.value.maxSessions) <= 100)) &&
    !isSaving.value
);
const canCreateResource = computed(
  () =>
    resourceForm.value.name.trim() &&
    (resourceForm.value.resourceType !== 'user' || resourceForm.value.userId) &&
    !isSaving.value
);
const procedureSubmitLabel = computed(() =>
  editingProcedureId.value
    ? t('CALENDAR.SETTINGS.SAVE_PROCEDURE')
    : t('CALENDAR.SETTINGS.ADD_PROCEDURE')
);
const resourceSubmitLabel = computed(() =>
  editingResourceId.value
    ? t('CALENDAR.SETTINGS.SAVE_RESOURCE')
    : t('CALENDAR.SETTINGS.ADD_RESOURCE')
);
const resourceTypeLabel = resourceType =>
  ({
    room: t('CALENDAR.SETTINGS.RESOURCE_TYPES.ROOM'),
    equipment: t('CALENDAR.SETTINGS.RESOURCE_TYPES.EQUIPMENT'),
    generic: t('CALENDAR.SETTINGS.RESOURCE_TYPES.GENERIC'),
  })[resourceType] || t('CALENDAR.SETTINGS.RESOURCE_TYPES.GENERIC');
const resourceToggleLabel = resource =>
  resource.active
    ? t('CALENDAR.SETTINGS.DEACTIVATE_RESOURCE')
    : t('CALENDAR.SETTINGS.ACTIVATE_RESOURCE');
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
const agentOptions = computed(() =>
  agents.value.map(agent => ({
    value: agent.id,
    label: agent.name || agent.email,
  }))
);
const selectedBookingBoard = computed(() =>
  boards.value.find(board => String(board.id) === bookingPageForm.value.boardId)
);
const bookingStageOptions = computed(
  () => selectedBookingBoard.value?.stages_summary || []
);
const bookingPageUrl = computed(() => {
  if (!bookingPage.value?.public_token) return '';

  return `${window.location.origin}/agendar/${bookingPage.value.public_token}`;
});
const bookingEmbedCode = computed(() => {
  if (!bookingPageUrl.value) return '';

  return `<iframe src="${bookingPageUrl.value}" title="${t('CALENDAR.SETTINGS.BOOKING_PAGE')}" width="100%" height="720" frameborder="0"></iframe>`;
});
const publicProcedureUrl = procedure =>
  bookingPageUrl.value && procedure.public_slug
    ? `${bookingPageUrl.value}/${procedure.public_slug}`
    : '';
const privateBookingUrl = link =>
  `${window.location.origin}/agendar/convite/${link.token}`;
const selectProfessional = userId => {
  resourceForm.value.userId = userId;
  const agent = agentOptions.value.find(
    item => String(item.value) === String(userId)
  );
  if (agent && !resourceForm.value.name.trim()) {
    resourceForm.value.name = agent.label;
  }
};
const orderedAvailabilityRules = computed(() =>
  [...availabilityRules.value].sort((firstRule, secondRule) => {
    if (firstRule.date && secondRule.date) {
      return firstRule.date.localeCompare(secondRule.date);
    }
    if (firstRule.date) return 1;
    if (secondRule.date) return -1;
    if (firstRule.weekday !== secondRule.weekday) {
      return firstRule.weekday - secondRule.weekday;
    }

    return (firstRule.starts_at_local || '').localeCompare(
      secondRule.starts_at_local || ''
    );
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
    bufferBeforeMinutes: '0',
    bufferAfterMinutes: '0',
    locationType: 'in_person',
    color: '#00B8C6',
    recurrenceAllowed: false,
    maxSessions: '',
    resourceIds: [],
    publicBookingEnabled: false,
    publicTitle: '',
    publicDescription: '',
    publicSlug: '',
  };
  resourceForm.value = { name: '', resourceType: 'generic', userId: '' };
  availabilityResourceId.value = null;
  availabilityRules.value = [];
  availabilityForm.value = {
    weekday: '1',
    startsAtLocal: '09:00',
    endsAtLocal: '18:00',
  };
  exceptionForm.value = {
    kind: 'block',
    date: '',
    startsAtLocal: '',
    endsAtLocal: '',
  };
  error.value = '';
  editingProcedureId.value = null;
  editingResourceId.value = null;
  isProcedureEditorOpen.value = false;
  isResourceEditorOpen.value = false;
  bookingPage.value = null;
  bookingLinks.value = [];
  googleCalendarConnection.value = null;
  isLoadingGoogleCalendarConnection.value = false;
  bookingLinkForm.value = { procedureId: '', expiresAt: '', maxUses: '' };
  bookingPageForm.value = {
    active: false,
    title: '',
    description: '',
    duplicatePolicy: 'create_new',
    minimumNoticeMinutes: '1440',
    maximumNoticeDays: '60',
    slotIntervalMinutes: '15',
    boardId: '',
    stageId: '',
    inboxId: '',
    captchaProvider: '',
    captchaSiteKey: '',
    publicFormFields: [],
  };
};

const procedurePayload = () => {
  const procedure = {
    name: procedureForm.value.name.trim(),
    duration_minutes: Number(procedureForm.value.durationMinutes),
    buffer_before_minutes: Number(procedureForm.value.bufferBeforeMinutes),
    buffer_after_minutes: Number(procedureForm.value.bufferAfterMinutes),
    location_type: procedureForm.value.locationType,
    color: procedureForm.value.color || null,
    recurrence_allowed: procedureForm.value.recurrenceAllowed,
    resource_ids: procedureForm.value.resourceIds.map(Number),
    active: true,
    public_booking_enabled: procedureForm.value.publicBookingEnabled,
    public_title: procedureForm.value.publicTitle.trim() || null,
    public_description: procedureForm.value.publicDescription.trim() || null,
    public_slug: procedureForm.value.publicSlug.trim() || null,
  };
  if (procedure.recurrence_allowed) {
    procedure.max_sessions = Number(procedureForm.value.maxSessions);
  }
  return procedure;
};

const resetProcedureForm = () => {
  procedureForm.value = {
    name: '',
    durationMinutes: '50',
    recurrenceAllowed: false,
    maxSessions: '10',
    resourceIds: [],
    publicBookingEnabled: false,
    publicTitle: '',
    publicDescription: '',
    publicSlug: '',
  };
  editingProcedureId.value = null;
  isProcedureEditorOpen.value = false;
};

const resetResourceForm = () => {
  resourceForm.value = { name: '', resourceType: 'generic', userId: '' };
  editingResourceId.value = null;
  isResourceEditorOpen.value = false;
};

const loadGoogleCalendarConnection = async resourceId => {
  if (!resourceId) return;

  isLoadingGoogleCalendarConnection.value = true;
  try {
    const response = await CalendarAPI.getGoogleCalendarConnection(resourceId);
    googleCalendarConnection.value = response.data;
  } catch (loadError) {
    error.value = getErrorMessage(loadError);
  } finally {
    isLoadingGoogleCalendarConnection.value = false;
  }
};

const connectGoogleCalendar = async () => {
  if (!editingResourceId.value || isSaving.value) return;

  isSaving.value = true;
  error.value = '';
  try {
    const response = await CalendarAPI.getGoogleCalendarAuthorizationUrl(
      editingResourceId.value
    );
    window.location.assign(response.data.url);
  } catch (saveError) {
    error.value = getErrorMessage(saveError);
  } finally {
    isSaving.value = false;
  }
};

const disconnectGoogleCalendar = async () => {
  if (!editingResourceId.value || isSaving.value) return;

  isSaving.value = true;
  error.value = '';
  try {
    await CalendarAPI.disconnectGoogleCalendar(editingResourceId.value);
    googleCalendarConnection.value = {
      connected: false,
      status: 'disconnected',
    };
  } catch (saveError) {
    error.value = getErrorMessage(saveError);
  } finally {
    isSaving.value = false;
  }
};

const retryGoogleCalendar = async () => {
  if (!editingResourceId.value || isSaving.value) return;

  isSaving.value = true;
  error.value = '';
  try {
    const response = await CalendarAPI.retryGoogleCalendar(
      editingResourceId.value
    );
    googleCalendarConnection.value = response.data;
  } catch (saveError) {
    error.value = getErrorMessage(saveError);
  } finally {
    isSaving.value = false;
  }
};

const editResource = async resource => {
  isResourceEditorOpen.value = true;
  editingResourceId.value = resource.id;
  resourceForm.value = {
    name: resource.name,
    resourceType: resource.resource_type,
    userId: resource.user_id ? String(resource.user_id) : '',
  };
  await loadGoogleCalendarConnection(resource.id);
};

const editProcedure = procedure => {
  isProcedureEditorOpen.value = true;
  editingProcedureId.value = procedure.id;
  procedureForm.value = {
    name: procedure.name,
    durationMinutes: String(procedure.duration_minutes),
    bufferBeforeMinutes: String(procedure.buffer_before_minutes || 0),
    bufferAfterMinutes: String(procedure.buffer_after_minutes || 0),
    locationType: procedure.location_type || 'in_person',
    color: procedure.color || '#00B8C6',
    recurrenceAllowed: procedure.recurrence_allowed,
    maxSessions: procedure.max_sessions ? String(procedure.max_sessions) : '10',
    resourceIds: procedure.resource_ids || [],
    publicBookingEnabled: procedure.public_booking_enabled || false,
    publicTitle: procedure.public_title || '',
    publicDescription: procedure.public_description || '',
    publicSlug: procedure.public_slug || '',
  };
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

const applyBookingPage = page => {
  bookingPage.value = page;
  bookingPageForm.value = {
    active: page.active,
    title: page.title || '',
    description: page.description || '',
    duplicatePolicy: page.duplicate_policy,
    minimumNoticeMinutes: String(page.minimum_notice_minutes),
    maximumNoticeDays: String(page.maximum_notice_days),
    slotIntervalMinutes: String(page.slot_interval_minutes),
    boardId: page.kanban_board_id ? String(page.kanban_board_id) : '',
    stageId: page.kanban_stage_id ? String(page.kanban_stage_id) : '',
    inboxId: page.inbox_id ? String(page.inbox_id) : '',
    captchaProvider: page.captcha_provider || '',
    captchaSiteKey: page.captcha_site_key || '',
    publicFormFields: (page.public_form_fields || []).map(field => ({
      ...field,
      optionsText: (field.options || []).join(', '),
    })),
  };
};

const loadBookingPage = async () => {
  if (bookingPage.value || isLoading.value) return;

  isLoading.value = true;
  error.value = '';
  try {
    const [response, linksResponse] = await Promise.all([
      CalendarAPI.getBookingPage(),
      CalendarAPI.getBookingLinks(),
      boards.value.length
        ? Promise.resolve()
        : store.dispatch('kanbanBoards/fetchBoards'),
    ]);
    applyBookingPage(response.data);
    bookingLinks.value = linksResponse.data || [];
  } catch (loadError) {
    error.value = getErrorMessage(loadError);
  } finally {
    isLoading.value = false;
  }
};

const createBookingLink = async () => {
  if (isSaving.value) return;

  isSaving.value = true;
  error.value = '';
  try {
    const response = await CalendarAPI.createBookingLink({
      booking_link: {
        kanban_calendar_procedure_id: bookingLinkForm.value.procedureId || null,
        expires_at: bookingLinkForm.value.expiresAt || null,
        max_uses: bookingLinkForm.value.maxUses || null,
      },
    });
    bookingLinks.value = [response.data, ...bookingLinks.value];
    bookingLinkForm.value = { procedureId: '', expiresAt: '', maxUses: '' };
  } catch (saveError) {
    error.value = getErrorMessage(saveError);
  } finally {
    isSaving.value = false;
  }
};

const copyPrivateBookingLink = async link => {
  await copyTextToClipboard(privateBookingUrl(link));
};

const selectSettingsTab = tab => {
  activeTab.value = tab;
  if (tab === 'booking-page') loadBookingPage();
};

const selectBookingBoard = () => {
  bookingPageForm.value.stageId = '';
};

const addPublicFormField = () => {
  bookingPageForm.value.publicFormFields.push({
    key: '',
    label: '',
    kind: 'text',
    required: false,
    optionsText: '',
  });
};

const removePublicFormField = index => {
  bookingPageForm.value.publicFormFields.splice(index, 1);
};

const saveBookingPage = async () => {
  if (isSaving.value) return;

  isSaving.value = true;
  error.value = '';
  try {
    const response = await CalendarAPI.updateBookingPage({
      booking_page: {
        active: bookingPageForm.value.active,
        title: bookingPageForm.value.title.trim() || null,
        description: bookingPageForm.value.description.trim() || null,
        duplicate_policy: bookingPageForm.value.duplicatePolicy,
        minimum_notice_minutes: Number(
          bookingPageForm.value.minimumNoticeMinutes
        ),
        maximum_notice_days: Number(bookingPageForm.value.maximumNoticeDays),
        slot_interval_minutes: Number(
          bookingPageForm.value.slotIntervalMinutes
        ),
        kanban_board_id: bookingPageForm.value.boardId || null,
        kanban_stage_id: bookingPageForm.value.stageId || null,
        inbox_id: bookingPageForm.value.inboxId || null,
        captcha_provider: bookingPageForm.value.captchaProvider || null,
        captcha_site_key: bookingPageForm.value.captchaSiteKey.trim() || null,
        public_form_fields: bookingPageForm.value.publicFormFields
          .filter(field => field.key.trim() && field.label.trim())
          .map(field => ({
            key: field.key.trim(),
            label: field.label.trim(),
            kind: field.kind,
            required: Boolean(field.required),
            options:
              field.kind === 'select'
                ? field.optionsText
                    .split(',')
                    .map(option => option.trim())
                    .filter(Boolean)
                : [],
          })),
      },
    });
    applyBookingPage(response.data);
  } catch (saveError) {
    error.value = getErrorMessage(saveError);
  } finally {
    isSaving.value = false;
  }
};

const copyBookingPageLink = async () => {
  if (!bookingPageUrl.value) return;

  await copyTextToClipboard(bookingPageUrl.value);
};

const copyBookingEmbed = async () => {
  if (!bookingEmbedCode.value) return;

  await copyTextToClipboard(bookingEmbedCode.value);
};

const copyProcedureBookingLink = async procedure => {
  const url = publicProcedureUrl(procedure);
  if (!url) return;

  await copyTextToClipboard(url);
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
    const procedure = procedurePayload();
    const response = editingProcedureId.value
      ? await CalendarAPI.updateProcedure(editingProcedureId.value, {
          procedure,
        })
      : await CalendarAPI.createProcedure({ procedure });
    procedures.value = editingProcedureId.value
      ? procedures.value.map(item =>
          item.id === response.data.id ? response.data : item
        )
      : [...procedures.value, response.data];
    resetProcedureForm();
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
    const existingResource = resources.value.find(
      item => item.id === editingResourceId.value
    );
    const resource = {
      name: resourceForm.value.name.trim(),
      resource_type: resourceForm.value.resourceType,
      timezone:
        existingResource?.timezone ||
        Intl.DateTimeFormat().resolvedOptions().timeZone,
      active: existingResource?.active ?? true,
      user_id: null,
    };
    if (resource.resource_type === 'user')
      resource.user_id = Number(resourceForm.value.userId);
    const response = editingResourceId.value
      ? await CalendarAPI.updateResource(editingResourceId.value, { resource })
      : await CalendarAPI.createResource({ resource });
    resources.value = editingResourceId.value
      ? resources.value.map(item =>
          item.id === response.data.id ? response.data : item
        )
      : [...resources.value, response.data];
    resetResourceForm();
    emit('updated');
  } catch (saveError) {
    error.value = getErrorMessage(saveError);
  } finally {
    isSaving.value = false;
  }
};

const toggleResource = async resource => {
  if (isSaving.value) return;

  isSaving.value = true;
  error.value = '';
  try {
    const response = await CalendarAPI.updateResource(resource.id, {
      resource: { active: !resource.active },
    });
    resources.value = resources.value.map(item =>
      item.id === response.data.id ? response.data : item
    );
    if (availabilityResourceId.value === resource.id && !response.data.active) {
      availabilityResourceId.value = null;
      availabilityRules.value = [];
    }
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

const addDateException = async () => {
  if (
    !availabilityResourceId.value ||
    !exceptionForm.value.date ||
    isSaving.value
  ) {
    return;
  }

  isSaving.value = true;
  error.value = '';
  try {
    const rule = {
      kind: exceptionForm.value.kind,
      date: exceptionForm.value.date,
      active: true,
    };
    if (exceptionForm.value.kind === 'date_override') {
      rule.starts_at_local = exceptionForm.value.startsAtLocal;
      rule.ends_at_local = exceptionForm.value.endsAtLocal;
    } else if (
      exceptionForm.value.startsAtLocal &&
      exceptionForm.value.endsAtLocal
    ) {
      rule.starts_at_local = exceptionForm.value.startsAtLocal;
      rule.ends_at_local = exceptionForm.value.endsAtLocal;
    }
    const response = await CalendarAPI.createAvailabilityRule(
      availabilityResourceId.value,
      { availability_rule: rule }
    );
    availabilityRules.value = [...availabilityRules.value, response.data];
    exceptionForm.value = {
      kind: 'block',
      date: '',
      startsAtLocal: '',
      endsAtLocal: '',
    };
  } catch (saveError) {
    error.value = getErrorMessage(saveError);
  } finally {
    isSaving.value = false;
  }
};

const availabilityRuleLabel = rule => {
  if (rule.kind === 'weekly_window') {
    return t('CALENDAR.SETTINGS.AVAILABILITY.RULE', {
      weekday: weekdayLabel(rule.weekday),
      start: rule.starts_at_local,
      end: rule.ends_at_local,
    });
  }
  if (rule.kind === 'date_override') {
    return t('CALENDAR.SETTINGS.AVAILABILITY.DATE_OVERRIDE_RULE', {
      date: rule.date,
      start: rule.starts_at_local,
      end: rule.ends_at_local,
    });
  }
  if (!rule.starts_at_local) {
    return t('CALENDAR.SETTINGS.AVAILABILITY.FULL_DAY_BLOCK_RULE', {
      date: rule.date,
    });
  }

  return t('CALENDAR.SETTINGS.AVAILABILITY.BLOCK_RULE', {
    date: rule.date,
    start: rule.starts_at_local,
    end: rule.ends_at_local,
  });
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
    width="3xl"
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
          id="calendar-settings-procedures-tab"
          type="button"
          role="tab"
          class="rounded px-3 py-1.5 text-sm font-medium outline-none focus:ring-2 focus:ring-n-brand/40"
          :class="
            activeTab === 'procedures'
              ? 'bg-n-surface-1 text-n-slate-12 shadow-sm'
              : 'text-n-slate-11'
          "
          :aria-selected="activeTab === 'procedures'"
          aria-controls="calendar-settings-procedures-panel"
          @click="selectSettingsTab('procedures')"
        >
          {{ t('CALENDAR.SETTINGS.PROCEDURES') }}
        </button>
        <button
          id="calendar-settings-resources-tab"
          type="button"
          role="tab"
          class="rounded px-3 py-1.5 text-sm font-medium outline-none focus:ring-2 focus:ring-n-brand/40"
          :class="
            activeTab === 'resources'
              ? 'bg-n-surface-1 text-n-slate-12 shadow-sm'
              : 'text-n-slate-11'
          "
          :aria-selected="activeTab === 'resources'"
          aria-controls="calendar-settings-resources-panel"
          @click="selectSettingsTab('resources')"
        >
          {{ t('CALENDAR.SETTINGS.RESOURCES') }}
        </button>
        <button
          id="calendar-settings-booking-page-tab"
          type="button"
          role="tab"
          class="rounded px-3 py-1.5 text-sm font-medium outline-none focus:ring-2 focus:ring-n-brand/40"
          :class="
            activeTab === 'booking-page'
              ? 'bg-n-surface-1 text-n-slate-12 shadow-sm'
              : 'text-n-slate-11'
          "
          :aria-selected="activeTab === 'booking-page'"
          aria-controls="calendar-settings-booking-page-panel"
          @click="selectSettingsTab('booking-page')"
        >
          {{ t('CALENDAR.SETTINGS.BOOKING_PAGE') }}
        </button>
      </div>

      <p v-if="isLoading" class="mb-0 text-sm text-n-slate-11">
        {{ t('CALENDAR.SETTINGS.LOADING') }}
      </p>
      <p v-else-if="error" class="mb-0 text-sm text-n-ruby-11" role="alert">
        {{ error }}
      </p>

      <template v-else-if="activeTab === 'procedures'">
        <section
          id="calendar-settings-procedures-panel"
          role="tabpanel"
          aria-labelledby="calendar-settings-procedures-tab"
          class="grid gap-4"
        >
          <div
            class="flex items-start justify-between gap-4 rounded-lg border border-n-weak bg-n-surface-2 p-4"
          >
            <div class="grid gap-1">
              <h4 class="text-sm font-semibold text-n-slate-12">
                {{ t('CALENDAR.SETTINGS.PROCEDURES') }}
              </h4>
              <p class="mb-0 text-sm text-n-slate-11">
                {{ t('CALENDAR.SETTINGS.PROCEDURES_DESCRIPTION') }}
              </p>
            </div>
            <NextButton
              type="button"
              size="sm"
              data-testid="calendar-add-procedure"
              :label="t('CALENDAR.SETTINGS.ADD_PROCEDURE')"
              @click="isProcedureEditorOpen = true"
            />
          </div>
          <form
            v-if="isProcedureEditorOpen"
            class="grid gap-3 rounded-lg border border-n-weak bg-n-surface-2 p-3"
            data-testid="calendar-procedure-form"
            @submit.prevent="createProcedure"
          >
            <div class="grid gap-3 sm:grid-cols-[minmax(0,1fr)_8rem]">
              <label class="grid gap-1.5">
                <span class="text-sm font-medium text-n-slate-12">
                  {{ t('CALENDAR.SETTINGS.PROCEDURE_NAME') }}
                </span>
                <input
                  v-model="procedureForm.name"
                  data-testid="calendar-procedure-name"
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
                  data-testid="calendar-procedure-duration"
                  min="5"
                  max="480"
                  type="number"
                  class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
                />
              </label>
            </div>
            <div class="grid gap-3 sm:grid-cols-4">
              <label class="grid gap-1.5">
                <span class="text-sm font-medium text-n-slate-12">
                  {{ t('CALENDAR.SETTINGS.BUFFER_BEFORE') }}
                </span>
                <input
                  v-model="procedureForm.bufferBeforeMinutes"
                  min="0"
                  max="120"
                  type="number"
                  class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
                />
              </label>
              <label class="grid gap-1.5">
                <span class="text-sm font-medium text-n-slate-12">
                  {{ t('CALENDAR.SETTINGS.BUFFER_AFTER') }}
                </span>
                <input
                  v-model="procedureForm.bufferAfterMinutes"
                  min="0"
                  max="120"
                  type="number"
                  class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
                />
              </label>
              <label class="grid gap-1.5">
                <span class="text-sm font-medium text-n-slate-12">
                  {{ t('CALENDAR.SETTINGS.LOCATION_TYPE') }}
                </span>
                <select
                  v-model="procedureForm.locationType"
                  class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
                >
                  <option value="in_person">
                    {{ t('CALENDAR.SETTINGS.LOCATION_TYPES.IN_PERSON') }}
                  </option>
                  <option value="video">
                    {{ t('CALENDAR.SETTINGS.LOCATION_TYPES.VIDEO') }}
                  </option>
                  <option value="phone">
                    {{ t('CALENDAR.SETTINGS.LOCATION_TYPES.PHONE') }}
                  </option>
                  <option value="other">
                    {{ t('CALENDAR.SETTINGS.LOCATION_TYPES.OTHER') }}
                  </option>
                </select>
              </label>
              <label class="grid gap-1.5">
                <span class="text-sm font-medium text-n-slate-12">
                  {{ t('CALENDAR.SETTINGS.PROCEDURE_COLOR') }}
                </span>
                <input
                  v-model="procedureForm.color"
                  type="color"
                  class="h-10 w-full rounded-md border border-n-weak bg-n-surface-1 p-1 outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
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
            <div
              class="grid gap-3 rounded-md border border-n-weak bg-n-surface-1 p-3"
            >
              <label
                class="flex items-center gap-2 text-sm font-medium text-n-slate-12"
              >
                <input
                  v-model="procedureForm.publicBookingEnabled"
                  data-testid="calendar-procedure-public-enabled"
                  type="checkbox"
                  class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
                />
                {{ t('CALENDAR.SETTINGS.PUBLIC_BOOKING_ENABLED') }}
              </label>
              <p class="mb-0 text-xs text-n-slate-11">
                {{ t('CALENDAR.SETTINGS.PUBLIC_BOOKING_HELP') }}
              </p>
              <div
                v-if="procedureForm.publicBookingEnabled"
                class="grid gap-3 sm:grid-cols-2"
              >
                <label class="grid gap-1.5">
                  <span class="text-sm font-medium text-n-slate-12">
                    {{ t('CALENDAR.SETTINGS.PUBLIC_TITLE') }}
                  </span>
                  <input
                    v-model="procedureForm.publicTitle"
                    type="text"
                    class="h-10 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
                  />
                </label>
                <label class="grid gap-1.5">
                  <span class="text-sm font-medium text-n-slate-12">
                    {{ t('CALENDAR.SETTINGS.PUBLIC_SLUG') }}
                  </span>
                  <input
                    v-model="procedureForm.publicSlug"
                    data-testid="calendar-procedure-public-slug"
                    type="text"
                    autocomplete="off"
                    class="h-10 rounded-md border border-n-weak bg-n-surface-2 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
                  />
                </label>
                <label class="grid gap-1.5 sm:col-span-2">
                  <span class="text-sm font-medium text-n-slate-12">
                    {{ t('CALENDAR.SETTINGS.PUBLIC_DESCRIPTION') }}
                  </span>
                  <textarea
                    v-model="procedureForm.publicDescription"
                    rows="2"
                    class="rounded-md border border-n-weak bg-n-surface-2 px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
                  />
                </label>
              </div>
            </div>
            <div class="flex flex-wrap items-center justify-between gap-3">
              <label class="flex items-center gap-2 text-sm text-n-slate-12">
                <input
                  v-model="procedureForm.recurrenceAllowed"
                  data-testid="calendar-procedure-recurrence"
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
                :label="procedureSubmitLabel"
                :disabled="!canCreateProcedure"
                :is-loading="isSaving"
              />
              <NextButton
                v-if="editingProcedureId"
                type="button"
                size="sm"
                outline
                :label="t('GENERAL.CANCEL')"
                @click="resetProcedureForm"
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
              <div class="grid gap-0.5">
                <span class="text-sm font-medium text-n-slate-12">{{
                  procedure.name
                }}</span>
                <span
                  v-if="procedure.public_booking_enabled"
                  class="text-xs text-n-brand"
                >
                  {{ t('CALENDAR.SETTINGS.PUBLIC_BOOKING_PUBLISHED') }}
                </span>
              </div>
              <span class="text-xs text-n-slate-11">
                {{
                  t('CALENDAR.SETTINGS.DURATION_VALUE', {
                    minutes: procedure.duration_minutes,
                  })
                }}
              </span>
              <NextButton
                type="button"
                xs
                outline
                data-testid="calendar-edit-procedure"
                :label="t('CALENDAR.SETTINGS.EDIT_PROCEDURE')"
                @click="editProcedure(procedure)"
              />
            </article>
          </div>
        </section>
      </template>

      <template v-else-if="activeTab === 'resources'">
        <section
          id="calendar-settings-resources-panel"
          role="tabpanel"
          aria-labelledby="calendar-settings-resources-tab"
          class="grid gap-4"
        >
          <div
            class="flex items-start justify-between gap-4 rounded-lg border border-n-weak bg-n-surface-2 p-4"
          >
            <div class="grid gap-1">
              <h4 class="text-sm font-semibold text-n-slate-12">
                {{ t('CALENDAR.SETTINGS.RESOURCES') }}
              </h4>
              <p class="mb-0 text-sm text-n-slate-11">
                {{ t('CALENDAR.SETTINGS.RESOURCES_DESCRIPTION') }}
              </p>
            </div>
            <NextButton
              type="button"
              size="sm"
              data-testid="calendar-add-resource"
              :label="t('CALENDAR.SETTINGS.ADD_RESOURCE')"
              @click="isResourceEditorOpen = true"
            />
          </div>
          <form
            v-if="isResourceEditorOpen"
            data-testid="calendar-resource-form"
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
                  data-testid="calendar-resource-name"
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
                  <option value="user">
                    {{ t('CALENDAR.SETTINGS.RESOURCE_TYPES.USER') }}
                  </option>
                  <option value="generic">
                    {{ t('CALENDAR.SETTINGS.RESOURCE_TYPES.GENERIC') }}
                  </option>
                </select>
              </label>
              <label
                v-if="resourceForm.resourceType === 'user'"
                class="grid gap-1"
              >
                <span class="text-sm font-medium text-n-slate-12">{{
                  t('CALENDAR.SETTINGS.PROFESSIONAL')
                }}</span>
                <select
                  v-model="resourceForm.userId"
                  class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                  @change="selectProfessional(resourceForm.userId)"
                >
                  <option value="">
                    {{ t('CALENDAR.SETTINGS.SELECT_PROFESSIONAL') }}
                  </option>
                  <option
                    v-for="agent in agentOptions"
                    :key="agent.value"
                    :value="String(agent.value)"
                  >
                    {{ agent.label }}
                  </option>
                </select>
              </label>
              <NextButton
                type="submit"
                size="sm"
                :label="resourceSubmitLabel"
                :disabled="!canCreateResource"
                :is-loading="isSaving"
              />
              <NextButton
                v-if="editingResourceId"
                type="button"
                size="sm"
                outline
                :label="t('GENERAL.CANCEL')"
                @click="resetResourceForm"
              />
            </div>
            <section
              v-if="editingResourceId"
              class="grid gap-2 rounded-md border border-n-weak bg-n-surface-1 p-3"
            >
              <div class="flex items-start justify-between gap-3">
                <div class="grid gap-0.5">
                  <h4 class="mb-0 text-sm font-medium text-n-slate-12">
                    {{ t('CALENDAR.SETTINGS.GOOGLE_CALENDAR.TITLE') }}
                  </h4>
                  <p class="mb-0 text-xs text-n-slate-11">
                    {{ t('CALENDAR.SETTINGS.GOOGLE_CALENDAR.HELP') }}
                  </p>
                </div>
                <span
                  class="text-xs font-medium text-n-slate-11"
                  :class="
                    googleCalendarConnection?.connected
                      ? 'text-n-teal-11'
                      : 'text-n-slate-11'
                  "
                >
                  {{
                    isLoadingGoogleCalendarConnection
                      ? t('CALENDAR.SETTINGS.GOOGLE_CALENDAR.LOADING')
                      : googleCalendarConnection?.connected
                        ? t('CALENDAR.SETTINGS.GOOGLE_CALENDAR.CONNECTED')
                        : t('CALENDAR.SETTINGS.GOOGLE_CALENDAR.DISCONNECTED')
                  }}
                </span>
              </div>
              <p
                v-if="googleCalendarConnection?.last_error"
                class="mb-0 text-xs text-n-ruby-11"
              >
                {{ googleCalendarConnection.last_error }}
              </p>
              <div class="flex flex-wrap gap-2">
                <NextButton
                  v-if="googleCalendarConnection?.retryable"
                  type="button"
                  size="sm"
                  outline
                  data-testid="calendar-retry-google-calendar"
                  :label="t('CALENDAR.SETTINGS.GOOGLE_CALENDAR.RETRY')"
                  :disabled="isLoadingGoogleCalendarConnection || isSaving"
                  @click="retryGoogleCalendar"
                />
                <NextButton
                  v-if="!googleCalendarConnection?.connected"
                  type="button"
                  size="sm"
                  outline
                  :label="t('CALENDAR.SETTINGS.GOOGLE_CALENDAR.CONNECT')"
                  :disabled="isLoadingGoogleCalendarConnection || isSaving"
                  @click="connectGoogleCalendar"
                />
                <NextButton
                  v-else
                  type="button"
                  size="sm"
                  outline
                  :label="t('CALENDAR.SETTINGS.GOOGLE_CALENDAR.DISCONNECT')"
                  :disabled="isSaving"
                  @click="disconnectGoogleCalendar"
                />
              </div>
            </section>
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
                data-testid="calendar-edit-resource"
                :label="t('CALENDAR.SETTINGS.EDIT_RESOURCE')"
                @click="editResource(resource)"
              />
              <NextButton
                type="button"
                xs
                outline
                :label="t('CALENDAR.SETTINGS.AVAILABILITY.OPEN')"
                @click="openAvailability(resource)"
              />
              <NextButton
                type="button"
                xs
                outline
                data-testid="calendar-toggle-resource"
                :label="resourceToggleLabel(resource)"
                :disabled="isSaving"
                @click="toggleResource(resource)"
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
            <form
              class="grid gap-2 rounded-md border border-dashed border-n-weak p-2.5 sm:grid-cols-[minmax(0,1fr)_8rem_7rem_7rem_auto] sm:items-end"
              @submit.prevent="addDateException"
            >
              <label class="grid gap-1">
                <span class="text-xs font-medium text-n-slate-12">{{
                  t('CALENDAR.SETTINGS.AVAILABILITY.EXCEPTION_TYPE')
                }}</span>
                <select
                  v-model="exceptionForm.kind"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                >
                  <option value="block">
                    {{ t('CALENDAR.SETTINGS.AVAILABILITY.BLOCK') }}
                  </option>
                  <option value="date_override">
                    {{ t('CALENDAR.SETTINGS.AVAILABILITY.DATE_OVERRIDE') }}
                  </option>
                </select>
              </label>
              <label class="grid gap-1">
                <span class="text-xs font-medium text-n-slate-12">{{
                  t('CALENDAR.SETTINGS.AVAILABILITY.DATE')
                }}</span>
                <input
                  v-model="exceptionForm.date"
                  type="date"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                />
              </label>
              <label class="grid gap-1">
                <span class="text-xs font-medium text-n-slate-12">{{
                  t('CALENDAR.SETTINGS.AVAILABILITY.START')
                }}</span>
                <input
                  v-model="exceptionForm.startsAtLocal"
                  type="time"
                  :required="exceptionForm.kind === 'date_override'"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                />
              </label>
              <label class="grid gap-1">
                <span class="text-xs font-medium text-n-slate-12">{{
                  t('CALENDAR.SETTINGS.AVAILABILITY.END')
                }}</span>
                <input
                  v-model="exceptionForm.endsAtLocal"
                  type="time"
                  :required="exceptionForm.kind === 'date_override'"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-2 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                />
              </label>
              <NextButton
                type="submit"
                size="sm"
                :label="t('CALENDAR.SETTINGS.AVAILABILITY.ADD_EXCEPTION')"
                :disabled="isSaving || !exceptionForm.date"
              />
            </form>
            <p
              v-if="isLoadingAvailability"
              class="mb-0 text-sm text-n-slate-11"
            >
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
                <span>{{ availabilityRuleLabel(rule) }}</span>
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
        </section>
      </template>

      <section
        v-else
        id="calendar-settings-booking-page-panel"
        role="tabpanel"
        aria-labelledby="calendar-settings-booking-page-tab"
        class="grid gap-4"
      >
        <div
          class="grid gap-1 rounded-lg border border-n-weak bg-n-surface-2 p-4"
        >
          <h4 class="text-sm font-semibold text-n-slate-12">
            {{ t('CALENDAR.SETTINGS.BOOKING_PAGE') }}
          </h4>
          <p class="mb-0 text-sm text-n-slate-11">
            {{ t('CALENDAR.SETTINGS.BOOKING_PAGE_DESCRIPTION') }}
          </p>
        </div>
        <form
          v-if="bookingPage"
          data-testid="calendar-booking-page-form"
          class="grid gap-4 rounded-lg border border-n-weak bg-n-surface-2 p-4"
          @submit.prevent="saveBookingPage"
        >
          <label
            class="flex items-center gap-2 text-sm font-medium text-n-slate-12"
          >
            <input
              v-model="bookingPageForm.active"
              type="checkbox"
              class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
            />
            {{ t('CALENDAR.SETTINGS.BOOKING_PAGE_ACTIVE') }}
          </label>
          <div class="grid gap-3 sm:grid-cols-2">
            <label class="grid gap-1.5">
              <span class="text-sm font-medium text-n-slate-12">
                {{ t('CALENDAR.SETTINGS.BOOKING_PAGE_TITLE') }}
              </span>
              <input
                v-model="bookingPageForm.title"
                type="text"
                class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
              />
            </label>
            <label class="grid gap-1.5">
              <span class="text-sm font-medium text-n-slate-12">
                {{ t('CALENDAR.SETTINGS.DUPLICATE_POLICY') }}
              </span>
              <select
                v-model="bookingPageForm.duplicatePolicy"
                class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
              >
                <option value="create_new">
                  {{ t('CALENDAR.SETTINGS.DUPLICATE_POLICIES.CREATE_NEW') }}
                </option>
                <option value="open_or_recent">
                  {{ t('CALENDAR.SETTINGS.DUPLICATE_POLICIES.OPEN_OR_RECENT') }}
                </option>
                <option value="most_recent">
                  {{ t('CALENDAR.SETTINGS.DUPLICATE_POLICIES.MOST_RECENT') }}
                </option>
              </select>
            </label>
          </div>
          <label class="grid gap-1.5">
            <span class="text-sm font-medium text-n-slate-12">
              {{ t('CALENDAR.SETTINGS.BOOKING_PAGE_DESCRIPTION_LABEL') }}
            </span>
            <textarea
              v-model="bookingPageForm.description"
              rows="2"
              class="rounded-md border border-n-weak bg-n-surface-1 px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
            />
          </label>
          <div class="grid gap-3 sm:grid-cols-3">
            <label class="grid gap-1.5">
              <span class="text-sm font-medium text-n-slate-12">
                {{ t('CALENDAR.SETTINGS.MINIMUM_NOTICE') }}
              </span>
              <input
                v-model="bookingPageForm.minimumNoticeMinutes"
                min="0"
                type="number"
                class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
              />
            </label>
            <label class="grid gap-1.5">
              <span class="text-sm font-medium text-n-slate-12">
                {{ t('CALENDAR.SETTINGS.MAXIMUM_NOTICE') }}
              </span>
              <input
                v-model="bookingPageForm.maximumNoticeDays"
                min="1"
                type="number"
                class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
              />
            </label>
            <label class="grid gap-1.5">
              <span class="text-sm font-medium text-n-slate-12">
                {{ t('CALENDAR.SETTINGS.SLOT_INTERVAL') }}
              </span>
              <select
                v-model="bookingPageForm.slotIntervalMinutes"
                class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
              >
                <option
                  v-for="interval in [5, 10, 15, 20, 30, 60]"
                  :key="interval"
                  :value="String(interval)"
                >
                  {{ interval }}
                </option>
              </select>
            </label>
          </div>
          <div class="grid gap-3 sm:grid-cols-3">
            <label class="grid gap-1.5">
              <span class="text-sm font-medium text-n-slate-12">
                {{ t('CALENDAR.SETTINGS.DESTINATION_BOARD') }}
              </span>
              <select
                v-model="bookingPageForm.boardId"
                class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                @change="selectBookingBoard"
              >
                <option value="">
                  {{ t('CALENDAR.SETTINGS.SELECT_DESTINATION') }}
                </option>
                <option
                  v-for="board in boards"
                  :key="board.id"
                  :value="String(board.id)"
                >
                  {{ board.name }}
                </option>
              </select>
            </label>
            <label class="grid gap-1.5">
              <span class="text-sm font-medium text-n-slate-12">
                {{ t('CALENDAR.SETTINGS.DESTINATION_STAGE') }}
              </span>
              <select
                v-model="bookingPageForm.stageId"
                :disabled="!bookingPageForm.boardId"
                class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
              >
                <option value="">
                  {{ t('CALENDAR.SETTINGS.SELECT_DESTINATION') }}
                </option>
                <option
                  v-for="stage in bookingStageOptions"
                  :key="stage.id"
                  :value="String(stage.id)"
                >
                  {{ stage.name }}
                </option>
              </select>
            </label>
            <label class="grid gap-1.5">
              <span class="text-sm font-medium text-n-slate-12">
                {{ t('CALENDAR.SETTINGS.DESTINATION_INBOX') }}
              </span>
              <select
                v-model="bookingPageForm.inboxId"
                class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
              >
                <option value="">
                  {{ t('CALENDAR.SETTINGS.SELECT_DESTINATION') }}
                </option>
                <option
                  v-for="inbox in inboxes"
                  :key="inbox.id"
                  :value="String(inbox.id)"
                >
                  {{ inbox.name }}
                </option>
              </select>
            </label>
          </div>
          <div class="flex flex-wrap items-center justify-between gap-3">
            <div
              class="min-w-0 flex-1 rounded-md border border-n-weak bg-n-surface-1 px-3 py-2 text-xs text-n-slate-11 break-all"
            >
              {{ bookingPageUrl }}
            </div>
            <NextButton
              type="button"
              size="sm"
              outline
              :label="t('CALENDAR.SETTINGS.COPY_LINK')"
              @click="copyBookingPageLink"
            />
            <NextButton
              type="button"
              size="sm"
              outline
              :label="t('CALENDAR.SETTINGS.COPY_EMBED')"
              @click="copyBookingEmbed"
            />
            <NextButton
              type="submit"
              size="sm"
              :label="t('GENERAL.SAVE')"
              :is-loading="isSaving"
            />
          </div>
          <section class="grid gap-2 border-t border-n-weak pt-4">
            <div class="grid gap-1">
              <h5 class="text-sm font-semibold text-n-slate-12">
                {{ t('CALENDAR.SETTINGS.PUBLISHED_PROCEDURES') }}
              </h5>
              <p class="mb-0 text-xs text-n-slate-11">
                {{ t('CALENDAR.SETTINGS.PUBLISHED_PROCEDURES_HELP') }}
              </p>
            </div>
            <p
              v-if="!procedures.some(item => item.public_booking_enabled)"
              class="mb-0 text-sm text-n-slate-11"
            >
              {{ t('CALENDAR.SETTINGS.NO_PUBLISHED_PROCEDURES') }}
            </p>
            <div
              v-for="procedure in procedures.filter(
                item => item.public_booking_enabled
              )"
              :key="procedure.id"
              class="flex items-center justify-between gap-3 rounded-md border border-n-weak bg-n-surface-1 px-3 py-2"
            >
              <div class="grid min-w-0 gap-0.5">
                <span class="truncate text-sm font-medium text-n-slate-12">
                  {{ procedure.public_title || procedure.name }}
                </span>
                <span class="truncate text-xs text-n-slate-11">
                  {{ publicProcedureUrl(procedure) }}
                </span>
              </div>
              <NextButton
                type="button"
                xs
                outline
                :label="t('CALENDAR.SETTINGS.COPY_LINK')"
                @click="copyProcedureBookingLink(procedure)"
              />
            </div>
          </section>
          <section class="grid gap-3 border-t border-n-weak pt-4">
            <div class="flex items-center justify-between gap-3">
              <div class="grid gap-1">
                <h5 class="text-sm font-semibold text-n-slate-12">
                  {{ t('CALENDAR.SETTINGS.PUBLIC_FORM_FIELDS') }}
                </h5>
                <p class="mb-0 text-xs text-n-slate-11">
                  {{ t('CALENDAR.SETTINGS.PUBLIC_FORM_FIELDS_HELP') }}
                </p>
              </div>
              <NextButton
                type="button"
                xs
                outline
                :label="t('CALENDAR.SETTINGS.ADD_PUBLIC_FORM_FIELD')"
                @click="addPublicFormField"
              />
            </div>
            <div
              v-for="(field, index) in bookingPageForm.publicFormFields"
              :key="index"
              class="grid gap-2 sm:grid-cols-[9rem_minmax(0,1fr)_7rem_auto_auto] sm:items-end"
            >
              <input
                v-model="field.key"
                :placeholder="t('CALENDAR.SETTINGS.PUBLIC_FIELD_KEY')"
                class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-2 text-sm outline-none focus:border-n-brand"
              />
              <input
                v-model="field.label"
                :placeholder="t('CALENDAR.SETTINGS.PUBLIC_FIELD_LABEL')"
                class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-2 text-sm outline-none focus:border-n-brand"
              />
              <select
                v-model="field.kind"
                class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-2 text-sm outline-none focus:border-n-brand"
              >
                <option value="text">{{ t('CALENDAR.SETTINGS.TEXT') }}</option>
                <option value="date">{{ t('CALENDAR.SETTINGS.DATE') }}</option>
                <option value="select">
                  {{ t('CALENDAR.SETTINGS.SELECT') }}
                </option>
              </select>
              <input
                v-if="field.kind === 'select'"
                v-model="field.optionsText"
                :placeholder="t('CALENDAR.SETTINGS.SELECT_OPTIONS')"
                class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-2 text-sm outline-none focus:border-n-brand sm:col-span-2"
              />
              <label
                class="flex h-9 items-center gap-1 text-xs text-n-slate-11"
              >
                <input v-model="field.required" type="checkbox" />
                {{ t('CALENDAR.SETTINGS.REQUIRED') }}
              </label>
              <NextButton
                type="button"
                xs
                ghost
                icon="i-lucide-trash-2"
                :label="t('CALENDAR.SETTINGS.REMOVE_PUBLIC_FIELD')"
                @click="removePublicFormField(index)"
              />
            </div>
          </section>
          <section class="grid gap-3 border-t border-n-weak pt-4">
            <div class="grid gap-1">
              <h5 class="text-sm font-semibold text-n-slate-12">
                {{ t('CALENDAR.SETTINGS.CAPTCHA') }}
              </h5>
              <p class="mb-0 text-xs text-n-slate-11">
                {{ t('CALENDAR.SETTINGS.CAPTCHA_HELP') }}
              </p>
            </div>
            <div class="grid gap-3 sm:grid-cols-2">
              <label class="grid gap-1 text-xs font-medium text-n-slate-12">
                {{ t('CALENDAR.SETTINGS.CAPTCHA_PROVIDER') }}
                <select
                  v-model="bookingPageForm.captchaProvider"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-2 text-sm outline-none focus:border-n-brand"
                >
                  <option value="">
                    {{ t('CALENDAR.SETTINGS.CAPTCHA_DISABLED') }}
                  </option>
                  <option value="turnstile">
                    {{ t('CALENDAR.SETTINGS.TURNSTILE') }}
                  </option>
                </select>
              </label>
              <label class="grid gap-1 text-xs font-medium text-n-slate-12">
                {{ t('CALENDAR.SETTINGS.CAPTCHA_SITE_KEY') }}
                <input
                  v-model="bookingPageForm.captchaSiteKey"
                  :disabled="!bookingPageForm.captchaProvider"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-2 text-sm outline-none focus:border-n-brand disabled:cursor-not-allowed disabled:opacity-60"
                />
              </label>
            </div>
          </section>
          <section class="grid gap-3 border-t border-n-weak pt-4">
            <div class="grid gap-1">
              <h5 class="text-sm font-semibold text-n-slate-12">
                {{ t('CALENDAR.SETTINGS.PRIVATE_LINKS') }}
              </h5>
              <p class="mb-0 text-xs text-n-slate-11">
                {{ t('CALENDAR.SETTINGS.PRIVATE_LINKS_HELP') }}
              </p>
            </div>
            <div
              class="grid gap-2 sm:grid-cols-[minmax(0,1fr)_11rem_8rem_auto] sm:items-end"
            >
              <label class="grid gap-1 text-xs font-medium text-n-slate-12">
                {{ t('CALENDAR.SETTINGS.PRIVATE_LINK_PROCEDURE') }}
                <select
                  v-model="bookingLinkForm.procedureId"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-2 text-sm outline-none focus:border-n-brand"
                >
                  <option value="">
                    {{ t('CALENDAR.SETTINGS.PRIVATE_LINK_ANY_PROCEDURE') }}
                  </option>
                  <option
                    v-for="procedure in procedures.filter(
                      item => item.public_booking_enabled
                    )"
                    :key="procedure.id"
                    :value="String(procedure.id)"
                  >
                    {{ procedure.public_title || procedure.name }}
                  </option>
                </select>
              </label>
              <label class="grid gap-1 text-xs font-medium text-n-slate-12">
                {{ t('CALENDAR.SETTINGS.PRIVATE_LINK_EXPIRES') }}
                <input
                  v-model="bookingLinkForm.expiresAt"
                  type="datetime-local"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-2 text-sm outline-none focus:border-n-brand"
                />
              </label>
              <label class="grid gap-1 text-xs font-medium text-n-slate-12">
                {{ t('CALENDAR.SETTINGS.PRIVATE_LINK_MAX_USES') }}
                <input
                  v-model="bookingLinkForm.maxUses"
                  min="1"
                  type="number"
                  class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-2 text-sm outline-none focus:border-n-brand"
                />
              </label>
              <NextButton
                type="button"
                size="sm"
                :label="t('CALENDAR.SETTINGS.CREATE_PRIVATE_LINK')"
                :is-loading="isSaving"
                @click="createBookingLink"
              />
            </div>
            <p v-if="!bookingLinks.length" class="mb-0 text-sm text-n-slate-11">
              {{ t('CALENDAR.SETTINGS.NO_PRIVATE_LINKS') }}
            </p>
            <div
              v-for="link in bookingLinks"
              :key="link.id"
              class="flex items-center justify-between gap-3 rounded-md border border-n-weak bg-n-surface-1 px-3 py-2"
            >
              <span class="min-w-0 truncate text-xs text-n-slate-11">{{
                privateBookingUrl(link)
              }}</span>
              <NextButton
                type="button"
                xs
                outline
                :label="t('CALENDAR.SETTINGS.COPY_LINK')"
                @click="copyPrivateBookingLink(link)"
              />
            </div>
          </section>
        </form>
      </section>
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
