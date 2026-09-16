<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { copyTextToClipboard } from 'shared/helpers/clipboard';

import CalendarAPI from 'dashboard/api/calendar';
import NextButton from 'dashboard/components-next/button/Button.vue';
import RaevoField from 'dashboard/components-next/raevo/RaevoField.vue';
import {
  RAEVO_CONTROL_CLASS,
  RAEVO_SELECT_STANDALONE_CLASS,
  RAEVO_TEXTAREA_CLASS,
} from 'dashboard/components-next/raevo/raevoControl';

// Página de agendamento e Integrações, no corpo das configurações da agenda.
// Procedimentos, disponibilidade, agendas e equipes vivem em `setup/`; quem
// escolhe a secção é a navegação lateral.
const props = defineProps({
  tab: { type: String, default: 'booking-page' },
});

const emit = defineEmits(['openProcedure']);

const { t } = useI18n();
const store = useStore();
const boards = useMapGetter('kanbanBoards/kanbanBoards');
const inboxes = useMapGetter('inboxes/getAllInboxes');
const activeTab = ref(props.tab);
const procedures = ref([]);
const isLoading = ref(false);
const isSaving = ref(false);
const error = ref('');
const bookingPage = ref(null);
const bookingLinks = ref([]);
const bookingLinkForm = ref({ procedureId: '', expiresAt: '', maxUses: '' });
const bookingPageForm = ref({
  active: false,
  title: '',
  description: '',
  clinicName: '',
  clinicAddress: '',
  clinicWhatsapp: '',
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

// Ligação da clínica ao Feegow: token, validade e importação da agenda.
const feegowConnection = ref(null);
const feegowProfessionals = ref([]);
const isSavingFeegow = ref(false);
const feegowToken = ref('');
const feegowTokenExpiresAt = ref('');

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
const getErrorMessage = errorResponse =>
  errorResponse?.response?.data?.message ||
  errorResponse?.message ||
  t('CALENDAR.SETTINGS.SAVE_ERROR');

const formatSyncTime = value =>
  new Intl.DateTimeFormat(undefined, {
    dateStyle: 'short',
    timeStyle: 'short',
  }).format(new Date(value));

const applyBookingPage = page => {
  bookingPage.value = page;
  bookingPageForm.value = {
    active: page.active,
    title: page.title || '',
    description: page.description || '',
    clinicName: page.clinic_name || '',
    clinicAddress: page.clinic_address || '',
    clinicWhatsapp: page.clinic_whatsapp || '',
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

// «Links por procedimento» só lista os procedimentos com autoagendamento ligado,
// e ele vem desligado. A lista vazia mandava «publicar» — palavra que não existe
// em botão nenhum —, por isso quem criou procedimentos não os via aparecer. O
// atalho abre o procedimento já com o interruptor ligado; gravar continua a
// ser uma decisão da pessoa.
// A API devolve também os arquivados; oferecer um link — ou ativar o
// autoagendamento — de um procedimento que já saiu de uso não faz sentido.
const linkableProcedures = computed(() =>
  procedures.value.filter(procedure => procedure.active !== false)
);

const enableProcedureBooking = procedure => {
  emit('openProcedure', procedure.id);
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
        clinic_name: bookingPageForm.value.clinicName.trim() || null,
        clinic_address: bookingPageForm.value.clinicAddress.trim() || null,
        clinic_whatsapp: bookingPageForm.value.clinicWhatsapp.trim() || null,
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

const loadFeegowProfessionals = async () => {
  if (!feegowConnection.value?.connected) {
    feegowProfessionals.value = [];
    return;
  }

  const professionals = await CalendarAPI.getFeegowProfessionals();
  feegowProfessionals.value = professionals.data || [];
};

const loadFeegowConnection = async () => {
  try {
    const response = await CalendarAPI.getFeegowConnection();
    feegowConnection.value = response.data;
    await loadFeegowProfessionals();
  } catch {
    // Sem Feegow configurado a agenda continua a funcionar; a secção fica no
    // estado «não ligado» em vez de derrubar as configurações.
    feegowProfessionals.value = [];
  }
};

const saveFeegowConnection = async () => {
  if (isSavingFeegow.value || !feegowToken.value.trim()) return;

  isSavingFeegow.value = true;
  error.value = '';
  try {
    const response = await CalendarAPI.updateFeegowConnection({
      feegow_connection: {
        api_token: feegowToken.value.trim(),
        token_expires_at: feegowTokenExpiresAt.value,
      },
    });
    // A resposta do próprio salvamento é o estado novo: voltar a perguntar ao
    // servidor só para reescrever o mesmo seria uma ida e volta a mais.
    feegowConnection.value = response.data;
    feegowToken.value = '';
    await loadFeegowProfessionals();
  } catch (saveError) {
    error.value = getErrorMessage(saveError);
  } finally {
    isSavingFeegow.value = false;
  }
};

const syncFeegowConnection = async () => {
  if (isSavingFeegow.value) return;

  isSavingFeegow.value = true;
  error.value = '';
  try {
    const response = await CalendarAPI.syncFeegowConnection();
    feegowConnection.value = response.data;
  } catch (syncError) {
    if (syncError?.response?.data?.status) {
      feegowConnection.value = syncError.response.data;
    } else {
      error.value = getErrorMessage(syncError);
    }
  } finally {
    isSavingFeegow.value = false;
  }
};

const disconnectFeegow = async () => {
  if (isSavingFeegow.value) return;

  isSavingFeegow.value = true;
  try {
    await CalendarAPI.disconnectFeegow();
    feegowConnection.value = {
      connected: false,
      status: 'disconnected',
      has_token: false,
    };
    feegowProfessionals.value = [];
  } catch (disconnectError) {
    error.value = getErrorMessage(disconnectError);
  } finally {
    isSavingFeegow.value = false;
  }
};

const feegowExpiryTone = computed(() => {
  if (feegowConnection.value?.token_expired) return 'text-n-ruby-11';
  if (feegowConnection.value?.token_expiring_soon) return 'text-n-amber-11';
  return 'text-n-slate-11';
});

const loadProcedures = async () => {
  try {
    const response = await CalendarAPI.getProcedures();
    procedures.value = response.data || [];
  } catch (loadError) {
    error.value = getErrorMessage(loadError);
  }
};

// Abrir já na página de agendamento — pela navegação lateral ou ao recarregar —
// tem de pedir a página: não há troca de aba que o faça.
const load = async () => {
  if (activeTab.value === 'booking-page') {
    await loadProcedures();
    await loadBookingPage();
  } else {
    await loadFeegowConnection();
  }
};

watch(
  () => props.tab,
  tab => {
    if (!tab || tab === activeTab.value) return;
    activeTab.value = tab;
    load();
  }
);

onMounted(load);
</script>

<template>
  <div>
    <div class="grid gap-4">
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

      <template v-if="activeTab === 'integrations'">
        <section
          class="grid gap-4"
          data-testid="calendar-settings-integrations-panel"
        >
          <!--
            O Feegow é da clínica inteira, não de uma agenda: o token fica aqui,
            e cada agenda escolhe depois o profissional que espelha.
          -->
          <section
            data-testid="calendar-feegow-section"
            class="grid gap-2 rounded-lg border border-n-weak bg-n-surface-1 p-3"
          >
            <div class="flex items-start justify-between gap-3">
              <div class="grid gap-0.5">
                <h4 class="mb-0 text-sm font-medium text-n-slate-12">
                  {{ t('CALENDAR.SETTINGS.FEEGOW.TITLE') }}
                </h4>
                <p class="mb-0 text-xs text-n-slate-11">
                  {{ t('CALENDAR.SETTINGS.FEEGOW.HELP') }}
                </p>
              </div>
              <span
                class="text-xs font-medium"
                :class="
                  feegowConnection?.connected
                    ? 'text-n-teal-11'
                    : 'text-n-slate-11'
                "
              >
                {{
                  feegowConnection?.connected
                    ? t('CALENDAR.SETTINGS.FEEGOW.CONNECTED')
                    : t('CALENDAR.SETTINGS.FEEGOW.DISCONNECTED')
                }}
              </span>
            </div>

            <p
              v-if="feegowConnection?.last_error"
              data-testid="calendar-feegow-error"
              role="alert"
              class="mb-0 flex items-start gap-1.5 text-xs text-n-ruby-11"
            >
              <i
                class="i-lucide-alert-triangle mt-0.5 size-3.5 shrink-0"
                aria-hidden="true"
              />
              {{ feegowConnection.last_error }}
            </p>

            <p
              v-if="feegowConnection?.has_token"
              data-testid="calendar-feegow-expiry"
              class="mb-0 flex items-start gap-1.5 text-xs"
              :class="feegowExpiryTone"
            >
              <i
                class="mt-0.5 size-3.5 shrink-0"
                :class="
                  feegowConnection.token_expired
                    ? 'i-lucide-alert-triangle'
                    : 'i-lucide-clock'
                "
                aria-hidden="true"
              />
              {{
                feegowConnection.token_expired
                  ? t('CALENDAR.SETTINGS.FEEGOW.EXPIRED')
                  : t('CALENDAR.SETTINGS.FEEGOW.EXPIRES_IN', {
                      days: feegowConnection.token_expires_in_days,
                    })
              }}
            </p>
            <p
              v-if="feegowConnection?.last_imported_at"
              data-testid="calendar-feegow-last-import"
              class="mb-0 text-xs text-n-slate-11"
            >
              {{
                t('CALENDAR.SETTINGS.FEEGOW.LAST_IMPORT', {
                  time: formatSyncTime(feegowConnection.last_imported_at),
                })
              }}
            </p>

            <div class="grid gap-2 sm:grid-cols-2">
              <RaevoField
                :label="t('CALENDAR.SETTINGS.FEEGOW.TOKEN')"
                :hint="t('CALENDAR.SETTINGS.FEEGOW.TOKEN_HINT')"
              >
                <template #default="{ controlClass, fieldId }">
                  <input
                    :id="fieldId"
                    v-model="feegowToken"
                    type="password"
                    autocomplete="off"
                    data-testid="calendar-feegow-token"
                    :placeholder="
                      feegowConnection?.has_token
                        ? t('CALENDAR.SETTINGS.FEEGOW.TOKEN_SAVED')
                        : ''
                    "
                    :class="controlClass"
                  />
                </template>
              </RaevoField>
              <RaevoField
                :label="t('CALENDAR.SETTINGS.FEEGOW.EXPIRES_AT')"
                :hint="t('CALENDAR.SETTINGS.FEEGOW.EXPIRES_AT_HINT')"
              >
                <template #default="{ controlClass, fieldId }">
                  <input
                    :id="fieldId"
                    v-model="feegowTokenExpiresAt"
                    type="date"
                    data-testid="calendar-feegow-expires-at"
                    :class="controlClass"
                  />
                </template>
              </RaevoField>
            </div>

            <div class="flex flex-wrap gap-2">
              <NextButton
                type="button"
                size="sm"
                data-testid="calendar-feegow-save"
                :label="t('CALENDAR.SETTINGS.FEEGOW.SAVE_TOKEN')"
                :disabled="isSavingFeegow || !feegowToken.trim()"
                @click="saveFeegowConnection"
              />
              <NextButton
                v-if="feegowConnection?.has_token"
                type="button"
                size="sm"
                outline
                icon="i-lucide-refresh-cw"
                data-testid="calendar-feegow-sync"
                :label="
                  isSavingFeegow
                    ? t('CALENDAR.SETTINGS.FEEGOW.SYNCING')
                    : t('CALENDAR.SETTINGS.FEEGOW.SYNC_NOW')
                "
                :disabled="isSavingFeegow"
                @click="syncFeegowConnection"
              />
              <NextButton
                v-if="feegowConnection?.has_token"
                type="button"
                size="sm"
                outline
                slate
                data-testid="calendar-feegow-disconnect"
                :label="t('CALENDAR.SETTINGS.FEEGOW.DISCONNECT')"
                :disabled="isSavingFeegow"
                @click="disconnectFeegow"
              />
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
          <!-- Quem a clínica é, na coluna da esquerda da página pública. -->
          <div class="grid gap-3 sm:grid-cols-3">
            <label class="grid gap-1.5">
              <span class="text-sm font-medium text-n-slate-12">
                {{ t('CALENDAR.SETTINGS.CLINIC_NAME') }}
              </span>
              <input
                v-model="bookingPageForm.clinicName"
                type="text"
                data-testid="calendar-booking-clinic-name"
                :class="RAEVO_CONTROL_CLASS"
              />
            </label>
            <label class="grid gap-1.5">
              <span class="text-sm font-medium text-n-slate-12">
                {{ t('CALENDAR.SETTINGS.CLINIC_ADDRESS') }}
              </span>
              <input
                v-model="bookingPageForm.clinicAddress"
                type="text"
                :class="RAEVO_CONTROL_CLASS"
              />
            </label>
            <label class="grid gap-1.5">
              <span class="text-sm font-medium text-n-slate-12">
                {{ t('CALENDAR.SETTINGS.CLINIC_WHATSAPP') }}
              </span>
              <input
                v-model="bookingPageForm.clinicWhatsapp"
                type="tel"
                :class="RAEVO_CONTROL_CLASS"
              />
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
              :label="t('CALENDAR_SETUP.COMMON.SAVE')"
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
  </div>
</template>
