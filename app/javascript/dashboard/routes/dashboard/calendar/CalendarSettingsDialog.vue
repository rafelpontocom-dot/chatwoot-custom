<script setup>
import { computed, nextTick, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { copyTextToClipboard } from 'shared/helpers/clipboard';

import CalendarAPI from 'dashboard/api/calendar';
import NextButton from 'dashboard/components-next/button/Button.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import RaevoField from 'dashboard/components-next/raevo/RaevoField.vue';
import CalendarWorkingHours from './CalendarWorkingHours.vue';
import {
  RAEVO_CONTROL_CLASS,
  RAEVO_SELECT_STANDALONE_CLASS,
  RAEVO_SWATCH_CLASS,
  RAEVO_TEXTAREA_CLASS,
} from 'dashboard/components-next/raevo/raevoControl';
import { RAEVO_DEFAULT_PROCEDURE_COLOR } from 'dashboard/constants/raevoPalette';

// A mesma definição serve às duas superfícies: em `inline` ela vira o corpo da
// página de configuração, sem moldura de diálogo e sem a fita de abas — quem
// escolhe a secção é a navegação lateral, como no Google Calendar.
const props = defineProps({
  inline: { type: Boolean, default: false },
  tab: { type: String, default: '' },
});

const emit = defineEmits(['updated']);

const { t } = useI18n();
const store = useStore();
const agents = useMapGetter('agents/getAgents');
const boards = useMapGetter('kanbanBoards/kanbanBoards');
const inboxes = useMapGetter('inboxes/getAllInboxes');
const dialog = ref(null);
const activeTab = ref(props.tab || 'procedures');
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
// Uma só definição do procedimento vazio. Estava escrita três vezes e as cópias
// divergiram: a usada depois de gravar perdeu os intervalos, a localização e a
// cor, e a partir do segundo procedimento o botão de guardar ficava desligado
// até alguém escrever nos dois intervalos.
const procedimentoVazio = () => ({
  name: '',
  durationMinutes: '50',
  bufferBeforeMinutes: '0',
  bufferAfterMinutes: '0',
  locationType: 'in_person',
  color: RAEVO_DEFAULT_PROCEDURE_COLOR,
  recurrenceAllowed: false,
  maxSessions: '10',
  resourceIds: [],
  publicBookingEnabled: false,
  publicTitle: '',
  publicDescription: '',
  publicSlug: '',
});
const procedureForm = ref(procedimentoVazio());
const resourceForm = ref({ name: '', resourceType: 'generic', userId: '' });
const exceptionForm = ref({
  kind: 'block',
  date: '',
  startsAtLocal: '',
  endsAtLocal: '',
});

const suggestedPublicSlug = computed(() => {
  const explicitSlug = procedureForm.value.publicSlug.trim();
  if (explicitSlug) return explicitSlug;

  return procedureForm.value.name
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
});
// O que falta para gravar, campo a campo. Antes era só um botão desligado, e
// ninguém sabia porquê: foi preciso adivinhar que eram os intervalos.
//
// Os limites são os de `KanbanCalendarProcedure`. As regras antigas do ecrã
// eram mais frouxas (duração > 0, intervalo >= 0) e deixavam passar o que o
// servidor depois recusava; a validação nativa do browser tapava isso, e com
// `novalidate` deixou de tapar.
const inteiroEntre = (valor, minimo, maximo) => {
  const numero = Number(valor);
  return (
    valor !== '' &&
    Number.isInteger(numero) &&
    numero >= minimo &&
    numero <= maximo
  );
};

const procedureErrors = computed(() => {
  const form = procedureForm.value;
  const erros = {};
  if (!form.name.trim()) {
    erros.name = t('CALENDAR.SETTINGS.VALIDATION.NAME_REQUIRED');
  }
  if (!inteiroEntre(form.durationMinutes, 5, 480)) {
    erros.duration = t('CALENDAR.SETTINGS.VALIDATION.DURATION_RANGE');
  }
  if (!inteiroEntre(form.bufferBeforeMinutes, 0, 120)) {
    erros.bufferBefore = t('CALENDAR.SETTINGS.VALIDATION.BUFFER_RANGE');
  }
  if (!inteiroEntre(form.bufferAfterMinutes, 0, 120)) {
    erros.bufferAfter = t('CALENDAR.SETTINGS.VALIDATION.BUFFER_RANGE');
  }
  if (form.recurrenceAllowed && !inteiroEntre(form.maxSessions, 1, 100)) {
    erros.maxSessions = t('CALENDAR.SETTINGS.VALIDATION.MAX_SESSIONS_RANGE');
  }
  if (form.publicBookingEnabled && !suggestedPublicSlug.value) {
    erros.publicSlug = t('CALENDAR.SETTINGS.VALIDATION.PUBLIC_SLUG_REQUIRED');
  }
  return erros;
});

// As mensagens só aparecem depois de tentar gravar. Um formulário acabado de
// abrir, todo a vermelho, grita antes de a pessoa ter feito alguma coisa.
const triedToSaveProcedure = ref(false);
const procedureFieldError = campo =>
  (triedToSaveProcedure.value && procedureErrors.value[campo]) || '';
const procedureFormElement = ref(null);

const canCreateProcedure = computed(
  () => !Object.keys(procedureErrors.value).length && !isSaving.value
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

/**
 * A lista abaixo da grade passa a mostrar só as exceções de data. As janelas
 * semanais já estão à vista nos sete dias — repeti-las era o que fazia da
 * definição de horários uma lista a crescer sem fim.
 */
const exceptionRules = computed(() =>
  orderedAvailabilityRules.value.filter(rule => rule.kind !== 'weekly_window')
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
  procedureForm.value = procedimentoVazio();
  triedToSaveProcedure.value = false;
  resourceForm.value = { name: '', resourceType: 'generic', userId: '' };
  availabilityResourceId.value = null;
  availabilityRules.value = [];
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
    public_slug: suggestedPublicSlug.value || null,
  };
  if (procedure.recurrence_allowed) {
    procedure.max_sessions = Number(procedureForm.value.maxSessions);
  }
  return procedure;
};

const resetProcedureForm = () => {
  procedureForm.value = procedimentoVazio();
  triedToSaveProcedure.value = false;
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
  triedToSaveProcedure.value = false;
  editingProcedureId.value = procedure.id;
  procedureForm.value = {
    name: procedure.name,
    durationMinutes: String(procedure.duration_minutes),
    bufferBeforeMinutes: String(procedure.buffer_before_minutes || 0),
    bufferAfterMinutes: String(procedure.buffer_after_minutes || 0),
    locationType: procedure.location_type || 'in_person',
    color: procedure.color || RAEVO_DEFAULT_PROCEDURE_COLOR,
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

// «Links por procedimento» só lista os procedimentos com autoagendamento ligado,
// e ele vem desligado. A lista vazia mandava «publicar» — palavra que não existe
// em botão nenhum —, por isso quem criou procedimentos não os via aparecer. O
// atalho leva ao procedimento já com o interruptor ligado; gravar continua a
// ser uma decisão da pessoa.
// A API devolve também os arquivados; oferecer um link — ou ativar o
// autoagendamento — de um procedimento que já saiu de uso não faz sentido.
const linkableProcedures = computed(() =>
  procedures.value.filter(procedure => procedure.active !== false)
);

const enableProcedureBooking = procedure => {
  selectSettingsTab('procedures');
  editProcedure(procedure);
  procedureForm.value.publicBookingEnabled = true;
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
  if (!props.inline) dialog.value?.open();
  await loadSettings();
  // Só `selectSettingsTab` carregava a página de agendamento, e só se chega lá
  // mudando de aba. Abrir já nela — pelo link da navegação lateral ou ao
  // recarregar — deixava o painel vazio: a aba começava ativa, o watcher não
  // disparava e a página nunca era pedida.
  if (activeTab.value === 'booking-page') await loadBookingPage();
};

watch(
  () => props.tab,
  tab => {
    if (!tab || tab === activeTab.value) return;
    selectSettingsTab(tab);
  }
);

onMounted(() => {
  if (props.inline) open();
});

const close = () => dialog.value?.close();

const createProcedure = async () => {
  triedToSaveProcedure.value = true;
  if (!canCreateProcedure.value) {
    // Leva o foco ao primeiro campo em falta: num formulário que rola, a
    // mensagem pode estar fora do ecrã, e quem usa teclado precisa de lá chegar.
    await nextTick();
    procedureFormElement.value?.querySelector('[aria-invalid="true"]')?.focus();
    return;
  }

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

// Mesmo critério da agenda: apaga quando é seguro, arquiva quando há consulta
// marcada. O backend já respondia; faltava o botão.
const removeProcedure = async procedure => {
  if (isSaving.value) return;

  const confirmacao = window.confirm(
    t('CALENDAR.SETTINGS.REMOVE_PROCEDURE_CONFIRM', { name: procedure.name })
  );
  if (!confirmacao) return;

  isSaving.value = true;
  error.value = '';
  try {
    const response = await CalendarAPI.archiveProcedure(procedure.id);
    if (response.data?.outcome === 'deleted') {
      procedures.value = procedures.value.filter(
        item => item.id !== procedure.id
      );
    } else {
      procedures.value = procedures.value.map(item =>
        item.id === response.data.id ? response.data : item
      );
    }
    if (editingProcedureId.value === procedure.id) resetProcedureForm();
    emit('updated');
  } catch (removeError) {
    error.value = getErrorMessage(removeError);
  } finally {
    isSaving.value = false;
  }
};

// Apagar de verdade quando dá, arquivar quando há consulta marcada — e dizer
// qual dos dois aconteceu, porque a diferença importa para quem administra.
const removeResource = async resource => {
  if (isSaving.value) return;

  const confirmacao = window.confirm(
    t('CALENDAR.SETTINGS.REMOVE_RESOURCE_CONFIRM', { name: resource.name })
  );
  if (!confirmacao) return;

  isSaving.value = true;
  error.value = '';
  try {
    const response = await CalendarAPI.archiveResource(resource.id);
    if (response.data?.outcome === 'deleted') {
      resources.value = resources.value.filter(item => item.id !== resource.id);
    } else {
      resources.value = resources.value.map(item =>
        item.id === response.data.id ? response.data : item
      );
    }
    if (availabilityResourceId.value === resource.id) {
      availabilityResourceId.value = null;
      availabilityRules.value = [];
    }
    emit('updated');
  } catch (removeError) {
    error.value = getErrorMessage(removeError);
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

/** A grade dos sete dias pede a criação; quem valida o intervalo é o servidor. */
const createWeeklyAvailability = async ({
  weekday,
  startsAtLocal,
  endsAtLocal,
}) => {
  if (!availabilityResourceId.value || isSaving.value) return;

  isSaving.value = true;
  error.value = '';
  try {
    const response = await CalendarAPI.createAvailabilityRule(
      availabilityResourceId.value,
      {
        availability_rule: {
          kind: 'weekly_window',
          weekday: Number(weekday),
          starts_at_local: startsAtLocal,
          ends_at_local: endsAtLocal,
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

/** Editar a hora no sítio, sem apagar e voltar a criar a regra. */
const updateWeeklyAvailability = async ({ rule, changes }) => {
  if (!availabilityResourceId.value || isSaving.value) return;

  isSaving.value = true;
  error.value = '';
  try {
    const response = await CalendarAPI.updateAvailabilityRule(
      availabilityResourceId.value,
      rule.id,
      { availability_rule: changes }
    );
    availabilityRules.value = availabilityRules.value.map(item =>
      item.id === rule.id ? response.data : item
    );
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
  <component
    :is="inline ? 'div' : Dialog"
    ref="dialog"
    v-bind="
      inline
        ? {}
        : {
            width: '3xl',
            overflowYAuto: true,
            title: t('CALENDAR.SETTINGS.TITLE'),
            description: t('CALENDAR.SETTINGS.DESCRIPTION'),
            showConfirmButton: false,
          }
    "
    @close="resetForms"
  >
    <div class="grid gap-4">
      <div
        v-if="!inline"
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

      <!--
        O erro é um aviso por cima do painel, não um substituto dele. Enquanto
        isto era um modal, trocar o conteúdo pela mensagem custava um fechar e
        abrir; numa página, uma gravação recusada apagava tudo o que estava em
        cima da mesa e obrigava a recarregar.
      -->
      <p
        v-if="error && !isLoading"
        class="mb-0 rounded-lg bg-n-ruby-2 px-3 py-2 text-sm text-n-ruby-11"
        role="alert"
        data-testid="calendar-settings-error"
      >
        {{ error }}
      </p>

      <template v-if="!isLoading && activeTab === 'procedures'">
        <section
          id="calendar-settings-procedures-panel"
          role="tabpanel"
          aria-labelledby="calendar-settings-procedures-tab"
          class="grid gap-4"
        >
          <div
            class="flex items-start justify-between gap-4"
            :class="
              inline ? '' : 'rounded-lg border border-n-weak bg-n-surface-2 p-4'
            "
          >
            <div v-if="!inline" class="grid gap-1">
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
          <!--
            `novalidate`: quem diz o que falta são as mensagens junto de cada
            campo. Com a validação nativa ligada, o browser mostrava um balão
            seu por cima e a nossa mensagem nunca chegava a aparecer.
          -->
          <form
            v-if="isProcedureEditorOpen"
            ref="procedureFormElement"
            class="grid gap-3 rounded-lg border border-n-weak bg-n-surface-2 p-3"
            data-testid="calendar-procedure-form"
            novalidate
            @submit.prevent="createProcedure"
          >
            <div class="grid gap-3 sm:grid-cols-[minmax(0,1fr)_8rem]">
              <RaevoField
                :label="t('CALENDAR.SETTINGS.PROCEDURE_NAME')"
                :error="procedureFieldError('name')"
                error-testid="calendar-procedure-name-error"
                required
              >
                <template #default="{ controlClass, fieldId, describedBy }">
                  <input
                    :id="fieldId"
                    v-model="procedureForm.name"
                    data-testid="calendar-procedure-name"
                    type="text"
                    required
                    :aria-invalid="!!procedureFieldError('name')"
                    :aria-describedby="describedBy"
                    :class="controlClass"
                  />
                </template>
              </RaevoField>
              <RaevoField
                :label="t('CALENDAR.SETTINGS.DURATION')"
                :error="procedureFieldError('duration')"
                required
              >
                <template #default="{ controlClass, fieldId, describedBy }">
                  <input
                    :id="fieldId"
                    v-model="procedureForm.durationMinutes"
                    data-testid="calendar-procedure-duration"
                    min="5"
                    max="480"
                    type="number"
                    required
                    :aria-invalid="!!procedureFieldError('duration')"
                    :aria-describedby="describedBy"
                    :class="controlClass"
                  />
                </template>
              </RaevoField>
            </div>
            <!--
              Os intervalos não levam asterisco: já vêm com 0, que é válido. A
              marca diria a quem preenche que tem de escrever ali, e não tem.
            -->
            <div class="grid gap-3 sm:grid-cols-4">
              <RaevoField
                :label="t('CALENDAR.SETTINGS.BUFFER_BEFORE')"
                :error="procedureFieldError('bufferBefore')"
              >
                <template #default="{ controlClass, fieldId, describedBy }">
                  <input
                    :id="fieldId"
                    v-model="procedureForm.bufferBeforeMinutes"
                    data-testid="calendar-procedure-buffer-before"
                    min="0"
                    max="120"
                    type="number"
                    :aria-invalid="!!procedureFieldError('bufferBefore')"
                    :aria-describedby="describedBy"
                    :class="controlClass"
                  />
                </template>
              </RaevoField>
              <RaevoField
                :label="t('CALENDAR.SETTINGS.BUFFER_AFTER')"
                :error="procedureFieldError('bufferAfter')"
              >
                <template #default="{ controlClass, fieldId, describedBy }">
                  <input
                    :id="fieldId"
                    v-model="procedureForm.bufferAfterMinutes"
                    data-testid="calendar-procedure-buffer-after"
                    min="0"
                    max="120"
                    type="number"
                    :aria-invalid="!!procedureFieldError('bufferAfter')"
                    :aria-describedby="describedBy"
                    :class="controlClass"
                  />
                </template>
              </RaevoField>
              <RaevoField
                :label="t('CALENDAR.SETTINGS.LOCATION_TYPE')"
                variant="select"
              >
                <template #default="{ controlClass, fieldId }">
                  <select
                    :id="fieldId"
                    v-model="procedureForm.locationType"
                    :class="controlClass"
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
                </template>
              </RaevoField>
              <RaevoField :label="t('CALENDAR.SETTINGS.PROCEDURE_COLOR')">
                <template #default="{ fieldId }">
                  <input
                    :id="fieldId"
                    v-model="procedureForm.color"
                    type="color"
                    :class="RAEVO_SWATCH_CLASS"
                  />
                </template>
              </RaevoField>
            </div>
            <RaevoField
              :label="t('CALENDAR.SETTINGS.PROCEDURE_RESOURCES')"
              :hint="t('CALENDAR.SETTINGS.PROCEDURE_RESOURCES_HELP')"
            >
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
            </RaevoField>
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
                <RaevoField :label="t('CALENDAR.SETTINGS.PUBLIC_TITLE')">
                  <template #default="{ controlClass, fieldId }">
                    <input
                      :id="fieldId"
                      v-model="procedureForm.publicTitle"
                      type="text"
                      :class="controlClass"
                    />
                  </template>
                </RaevoField>
                <RaevoField
                  :label="t('CALENDAR.SETTINGS.PUBLIC_SLUG')"
                  :error="procedureFieldError('publicSlug')"
                  required
                >
                  <template #default="{ controlClass, fieldId, describedBy }">
                    <input
                      :id="fieldId"
                      v-model="procedureForm.publicSlug"
                      data-testid="calendar-procedure-public-slug"
                      type="text"
                      autocomplete="off"
                      :aria-invalid="!!procedureFieldError('publicSlug')"
                      :aria-describedby="describedBy"
                      :class="controlClass"
                    />
                  </template>
                </RaevoField>
                <RaevoField
                  class="sm:col-span-2"
                  :label="t('CALENDAR.SETTINGS.PUBLIC_DESCRIPTION')"
                  variant="textarea"
                >
                  <template #default="{ controlClass, fieldId }">
                    <textarea
                      :id="fieldId"
                      v-model="procedureForm.publicDescription"
                      rows="2"
                      :class="controlClass"
                    />
                  </template>
                </RaevoField>
              </div>
            </div>
            <div class="flex flex-wrap items-end justify-between gap-3">
              <div class="flex flex-wrap items-end gap-3">
                <label
                  class="flex min-h-10 items-center gap-2 text-sm text-n-slate-12"
                >
                  <input
                    v-model="procedureForm.recurrenceAllowed"
                    data-testid="calendar-procedure-recurrence"
                    type="checkbox"
                    class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
                  />
                  {{ t('CALENDAR.SETTINGS.ALLOW_RECURRENCE') }}
                </label>
                <!-- O controlo canónico é `w-full`; a largura vive no invólucro. -->
                <RaevoField
                  v-if="procedureForm.recurrenceAllowed"
                  class="w-32"
                  :label="t('CALENDAR.SETTINGS.MAX_SESSIONS')"
                  :error="procedureFieldError('maxSessions')"
                  required
                >
                  <template #default="{ controlClass, fieldId, describedBy }">
                    <input
                      :id="fieldId"
                      v-model="procedureForm.maxSessions"
                      data-testid="calendar-procedure-max-sessions"
                      min="1"
                      max="100"
                      type="number"
                      :aria-invalid="!!procedureFieldError('maxSessions')"
                      :aria-describedby="describedBy"
                      :class="controlClass"
                    />
                  </template>
                </RaevoField>
              </div>
              <!--
                Cancelar aparece também ao criar. Só existia ao editar, e um
                procedimento novo aberto por engano não tinha como ser fechado.
              -->
              <div class="flex items-center gap-2">
                <NextButton
                  type="button"
                  size="sm"
                  outline
                  data-testid="calendar-procedure-cancel"
                  :label="t('CALENDAR.SETTINGS.CANCEL_EDIT')"
                  @click="resetProcedureForm"
                />
                <NextButton
                  type="submit"
                  size="sm"
                  data-testid="calendar-procedure-submit"
                  :label="procedureSubmitLabel"
                  :disabled="isSaving"
                  :is-loading="isSaving"
                />
              </div>
            </div>
            <p
              v-if="triedToSaveProcedure && !canCreateProcedure && !isSaving"
              data-testid="calendar-procedure-missing"
              class="mb-0 text-xs text-n-ruby-11"
              role="status"
            >
              {{ t('CALENDAR.SETTINGS.VALIDATION.FIX_MARKED_FIELDS') }}
            </p>
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
              <div class="grid min-w-0 gap-0.5">
                <span class="text-sm font-medium text-n-slate-12">{{
                  procedure.name
                }}</span>
                <span class="text-xs text-n-slate-11">
                  {{
                    t('CALENDAR.SETTINGS.DURATION_VALUE', {
                      minutes: procedure.duration_minutes,
                    })
                  }}
                  <span
                    v-if="procedure.public_booking_enabled"
                    class="text-n-brand"
                  >
                    · {{ t('CALENDAR.SETTINGS.PUBLIC_BOOKING_PUBLISHED') }}
                  </span>
                </span>
              </div>
              <!-- Mesmo defeito da lista de agendas: ações soltas no `justify-between`. -->
              <div class="flex shrink-0 items-center gap-1">
                <NextButton
                  type="button"
                  size="xs"
                  variant="ghost"
                  color="slate"
                  icon="i-lucide-pencil"
                  data-testid="calendar-edit-procedure"
                  :aria-label="t('CALENDAR.SETTINGS.EDIT_PROCEDURE')"
                  :title="t('CALENDAR.SETTINGS.EDIT_PROCEDURE')"
                  @click="editProcedure(procedure)"
                />
                <span class="mx-1 h-4 w-px bg-n-weak" aria-hidden="true" />
                <NextButton
                  type="button"
                  size="xs"
                  variant="ghost"
                  color="ruby"
                  icon="i-lucide-trash-2"
                  data-testid="calendar-remove-procedure"
                  :aria-label="t('CALENDAR.SETTINGS.REMOVE_PROCEDURE')"
                  :title="t('CALENDAR.SETTINGS.REMOVE_PROCEDURE')"
                  :disabled="isSaving"
                  @click="removeProcedure(procedure)"
                />
              </div>
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
            class="flex items-start justify-between gap-4"
            :class="
              inline ? '' : 'rounded-lg border border-n-weak bg-n-surface-2 p-4'
            "
          >
            <div v-if="!inline" class="grid gap-1">
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
                  :class="RAEVO_CONTROL_CLASS"
                />
              </label>
              <label class="grid gap-1.5">
                <span class="text-sm font-medium text-n-slate-12">
                  {{ t('CALENDAR.SETTINGS.RESOURCE_TYPE') }}
                </span>
                <select
                  v-model="resourceForm.resourceType"
                  :class="RAEVO_SELECT_STANDALONE_CLASS"
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
                  :class="RAEVO_SELECT_STANDALONE_CLASS"
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
                type="button"
                size="sm"
                outline
                data-testid="calendar-resource-cancel"
                :label="t('CALENDAR.SETTINGS.CANCEL_EDIT')"
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
              <div class="grid min-w-0 gap-0.5">
                <span
                  class="flex items-center gap-2 text-sm font-medium text-n-slate-12"
                >
                  {{ resource.name }}
                  <!--
                    Agenda inativa era idêntica a uma ativa na lista, o que fazia
                    parecer que desativar não tinha funcionado.
                  -->
                  <span
                    v-if="!resource.active"
                    data-testid="calendar-resource-archived"
                    class="rounded-full bg-n-amber-3 px-2 py-0.5 text-micro font-semibold text-n-amber-11"
                  >
                    {{ t('CALENDAR.SETTINGS.ARCHIVED') }}
                  </span>
                </span>
                <span class="text-xs text-n-slate-11">
                  {{ resourceTypeLabel(resource.resource_type) }}
                </span>
              </div>
              <!--
                As ações vivem num grupo próprio. Soltas como filhos diretos do
                `justify-between`, o espaço era repartido entre as cinco peças e
                os botões espalhavam-se pela linha, cada um a uma distância.
                Apagar fica afastado dos outros por ser o único destrutivo.
              -->
              <div class="flex shrink-0 items-center gap-1">
                <NextButton
                  type="button"
                  size="xs"
                  variant="ghost"
                  color="slate"
                  icon="i-lucide-pencil"
                  data-testid="calendar-edit-resource"
                  :aria-label="t('CALENDAR.SETTINGS.EDIT_RESOURCE')"
                  :title="t('CALENDAR.SETTINGS.EDIT_RESOURCE')"
                  @click="editResource(resource)"
                />
                <NextButton
                  type="button"
                  size="xs"
                  variant="ghost"
                  color="slate"
                  icon="i-lucide-clock"
                  data-testid="calendar-resource-availability"
                  :aria-label="t('CALENDAR.SETTINGS.AVAILABILITY.OPEN')"
                  :title="t('CALENDAR.SETTINGS.AVAILABILITY.OPEN')"
                  @click="openAvailability(resource)"
                />
                <NextButton
                  type="button"
                  size="xs"
                  variant="ghost"
                  color="slate"
                  :icon="
                    resource.active
                      ? 'i-lucide-archive'
                      : 'i-lucide-archive-restore'
                  "
                  data-testid="calendar-toggle-resource"
                  :aria-label="resourceToggleLabel(resource)"
                  :title="resourceToggleLabel(resource)"
                  :disabled="isSaving"
                  @click="toggleResource(resource)"
                />
                <span class="mx-1 h-4 w-px bg-n-weak" aria-hidden="true" />
                <NextButton
                  type="button"
                  size="xs"
                  variant="ghost"
                  color="ruby"
                  icon="i-lucide-trash-2"
                  data-testid="calendar-remove-resource"
                  :aria-label="t('CALENDAR.SETTINGS.REMOVE_RESOURCE')"
                  :title="t('CALENDAR.SETTINGS.REMOVE_RESOURCE')"
                  :disabled="isSaving"
                  @click="removeResource(resource)"
                />
              </div>
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
            <CalendarWorkingHours
              :rules="availabilityRules"
              :is-saving="isSaving"
              @create="createWeeklyAvailability"
              @update="updateWeeklyAvailability"
              @remove="removeAvailabilityRule"
            />
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
                  :class="RAEVO_SELECT_STANDALONE_CLASS"
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
                  :class="RAEVO_CONTROL_CLASS"
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
                  :class="RAEVO_CONTROL_CLASS"
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
                  :class="RAEVO_CONTROL_CLASS"
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
                v-if="!exceptionRules.length"
                class="mb-0 text-sm text-n-slate-11"
              >
                {{ t('CALENDAR.SETTINGS.AVAILABILITY.NO_EXCEPTIONS') }}
              </p>
              <div
                v-for="rule in exceptionRules"
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
                :class="RAEVO_CONTROL_CLASS"
              />
            </label>
            <label class="grid gap-1.5">
              <span class="text-sm font-medium text-n-slate-12">
                {{ t('CALENDAR.SETTINGS.DUPLICATE_POLICY') }}
              </span>
              <select
                v-model="bookingPageForm.duplicatePolicy"
                :class="RAEVO_SELECT_STANDALONE_CLASS"
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
              :class="RAEVO_TEXTAREA_CLASS"
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
                :class="RAEVO_CONTROL_CLASS"
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
                :class="RAEVO_CONTROL_CLASS"
              />
            </label>
            <label class="grid gap-1.5">
              <span class="text-sm font-medium text-n-slate-12">
                {{ t('CALENDAR.SETTINGS.SLOT_INTERVAL') }}
              </span>
              <select
                v-model="bookingPageForm.slotIntervalMinutes"
                :class="RAEVO_SELECT_STANDALONE_CLASS"
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
                :class="RAEVO_SELECT_STANDALONE_CLASS"
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
                :class="RAEVO_SELECT_STANDALONE_CLASS"
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
                :class="RAEVO_SELECT_STANDALONE_CLASS"
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
              v-if="!linkableProcedures.length"
              data-testid="calendar-procedure-links-empty"
              class="mb-0 text-sm text-n-slate-11"
            >
              {{ t('CALENDAR.SETTINGS.NO_PROCEDURES_FOR_LINKS') }}
            </p>
            <!--
              Todos os procedimentos, e não só os que têm autoagendamento. Só
              esses apareciam, o interruptor vem desligado, e a lista vazia
              mandava «publicar» — palavra que não existe em botão nenhum. Quem
              criou procedimentos não os via e achava que era defeito.
            -->
            <div
              v-for="procedure in linkableProcedures"
              :key="procedure.id"
              data-testid="calendar-procedure-link"
              class="flex items-center justify-between gap-3 rounded-md border border-n-weak bg-n-surface-1 px-3 py-2"
            >
              <div class="grid min-w-0 gap-0.5">
                <span class="truncate text-sm font-medium text-n-slate-12">
                  {{ procedure.public_title || procedure.name }}
                </span>
                <span
                  v-if="procedure.public_booking_enabled"
                  class="truncate text-xs text-n-slate-11"
                >
                  {{ publicProcedureUrl(procedure) }}
                </span>
                <span
                  v-else
                  class="flex items-center gap-1 text-xs text-n-slate-11"
                >
                  <i class="i-lucide-link-2-off size-3.5" aria-hidden="true" />
                  {{ t('CALENDAR.SETTINGS.PUBLIC_BOOKING_OFF') }}
                </span>
              </div>
              <NextButton
                v-if="procedure.public_booking_enabled"
                type="button"
                size="xs"
                variant="outline"
                data-testid="calendar-copy-procedure-link"
                :label="t('CALENDAR.SETTINGS.COPY_LINK')"
                @click="copyProcedureBookingLink(procedure)"
              />
              <NextButton
                v-else
                type="button"
                size="xs"
                variant="outline"
                data-testid="calendar-enable-procedure-booking"
                :label="t('CALENDAR.SETTINGS.ENABLE_PUBLIC_BOOKING')"
                @click="enableProcedureBooking(procedure)"
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
                :class="RAEVO_CONTROL_CLASS"
              />
              <input
                v-model="field.label"
                :placeholder="t('CALENDAR.SETTINGS.PUBLIC_FIELD_LABEL')"
                :class="RAEVO_CONTROL_CLASS"
              />
              <select
                v-model="field.kind"
                :class="RAEVO_SELECT_STANDALONE_CLASS"
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
                class="sm:col-span-2"
                :class="[RAEVO_CONTROL_CLASS]"
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
                  :class="RAEVO_SELECT_STANDALONE_CLASS"
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
                  :class="RAEVO_CONTROL_CLASS"
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
                  :class="RAEVO_SELECT_STANDALONE_CLASS"
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
                  :class="RAEVO_CONTROL_CLASS"
                />
              </label>
              <label class="grid gap-1 text-xs font-medium text-n-slate-12">
                {{ t('CALENDAR.SETTINGS.PRIVATE_LINK_MAX_USES') }}
                <input
                  v-model="bookingLinkForm.maxUses"
                  min="1"
                  type="number"
                  :class="RAEVO_CONTROL_CLASS"
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

    <template v-if="!inline" #footer>
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
  </component>
</template>
