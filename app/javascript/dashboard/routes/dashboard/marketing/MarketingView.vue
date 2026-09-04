<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import MarketingAPI from 'dashboard/api/marketing';
import KanbanBoardsAPI from 'dashboard/api/kanbanBoards';
import { intlLocale } from 'dashboard/composables/useAccountCurrency';
import { useMapGetter } from 'dashboard/composables/store';
import { frontendURL } from 'dashboard/helper/URLHelper';
import NextButton from 'dashboard/components-next/button/Button.vue';
import RaevoField from 'dashboard/components-next/raevo/RaevoField.vue';
import RaevoPageHeader from 'dashboard/components-next/raevo/RaevoPageHeader.vue';
import RaevoStamp from 'dashboard/components-next/raevo/RaevoStamp.vue';

// Raevo · Sereno — a tela operacional responde "de onde vieram os leads".
// Ligar o módulo e conectar plataformas vivem atrás da engrenagem, como no
// Financeiro. Ver docs/raevo-design-system.md §5.
const { t, locale } = useI18n();
const currentAccount = useMapGetter('getCurrentAccount');

const activeView = ref('panel');
const marketingModule = ref(null);
const summary = ref(null);
const touchpoints = ref([]);
const isLoading = ref(true);
const isLoadingTouchpoints = ref(false);
const isSavingModule = ref(false);
const loadError = ref('');
const saveError = ref('');

const accountId = computed(() => currentAccount.value?.id);
const permissions = computed(() => currentAccount.value?.permissions || []);
const canConfigure = computed(() =>
  ['administrator', 'marketing_configure'].some(permission =>
    permissions.value.includes(permission)
  )
);
const isEnabled = computed(() => Boolean(marketingModule.value?.enabled));

const captureRate = computed(() => summary.value?.capture_rate ?? 0);
const originRows = computed(() =>
  Object.entries(summary.value?.by_origin || {}).sort((a, b) => b[1] - a[1])
);
const campaignRows = computed(() =>
  Object.entries(summary.value?.top_campaigns || {}).sort((a, b) => b[1] - a[1])
);

const contactPath = contact =>
  frontendURL(`accounts/${accountId.value}/contacts/${contact.id}`);

// A data segue o idioma da conta; `toLocaleString` sozinho seguia o do browser
// e mostrava formato americano para uma clínica brasileira.
const formatMoment = value =>
  new Intl.DateTimeFormat(intlLocale(locale.value), {
    dateStyle: 'short',
    timeStyle: 'short',
  }).format(new Date(value));

// A barra existe para o número deixar de flutuar a meia tela do seu rótulo, e
// para a proporção entre origens se ler sem fazer conta.
const shareOf = (rows, count) => {
  const maior = Math.max(...rows.map(([, value]) => value), 1);
  return `${Math.round((count / maior) * 100)}%`;
};

// Entrada de leads: o token é a credencial de uma escrita pública, por isso
// aparece uma única vez e pode ser desligado na hora.
const intakeSources = ref([]);
const boards = ref([]);
const boardStages = ref([]);
const allowedInboxIds = ref([]);
const novaOrigem = ref({ name: '', board_id: '', stage_id: '', inbox_id: '' });
const tokenRevelado = ref('');
const intakeError = ref('');
const isSavingSource = ref(false);
const inboxes = useMapGetter('inboxes/getInboxes');

const intakeEndpoint = `${window.location.origin}/public/api/v1/marketing/intake`;
const inboxOptions = computed(() =>
  (inboxes.value || []).filter(
    inbox =>
      !allowedInboxIds.value.length || allowedInboxIds.value.includes(inbox.id)
  )
);

const connections = ref([]);
const leadForms = ref([]);
const connectionError = ref('');
const isBusyConnection = ref(false);

// Nome de plataforma não se traduz, mas também não entra cru no template:
// a regra do repo não distingue marca de texto de interface.
const metaLabel = 'Meta';
const soonPlatforms = ['Google Ads', 'TikTok Ads'];

// Desconectar zera o token mas guarda a linha, porque formulário e toque
// apontam para ela. Para a tela, porém, uma conexão sem token é o mesmo que
// não ter conexão: senão sobra "Atualizar páginas" — que chama o Meta sem
// token — e o botão de conectar some, deixando a pessoa sem saída.
const metaConnection = computed(() => {
  const record = connections.value.find(c => c.provider === 'meta');
  return record && record.status !== 'disconnected' ? record : null;
});
const metaPages = computed(() => metaConnection.value?.pages || []);

const loadConnections = async () => {
  const [connectionsResponse, formsResponse] = await Promise.all([
    MarketingAPI.getConnections(),
    MarketingAPI.getLeadForms(),
  ]);
  connections.value = connectionsResponse.data.payload || [];
  leadForms.value = formsResponse.data.payload || [];
};

// `OAuthException (200)` não diz a ninguém o que fazer. Quando o backend
// reconhece o motivo, ele vira a frase que aponta onde arrumar; quando não
// reconhece, vale a mensagem que veio — que nesse caso é nossa, do tipo
// "o app do Lead Ads não está configurado", e essa sim ajuda.
const REFUSAL_REASONS = ['permission', 'token_expired', 'rate_limit'];

const metaRefusalMessage = error => {
  const reason = error?.response?.data?.error_code;
  if (REFUSAL_REASONS.includes(reason)) {
    return t(`MARKETING.CONNECTIONS.ERRORS.${reason.toUpperCase()}`);
  }
  return error?.response?.data?.message || t('MARKETING.CONNECTIONS.ERROR');
};

// O Meta diz, por página, o que a conta conectada pode fazer nela. Sem
// `MANAGE` os leads não saem — e é melhor avisar antes do clique falhar.
// Página sincronizada antes deste campo existir não tem `tasks`: nesse caso
// não afirmamos nada.
const pageHasLimitedAccess = page =>
  Array.isArray(page.tasks) &&
  page.tasks.length > 0 &&
  !page.tasks.includes('MANAGE');

// Chamada que fala com o Meta: o erro dele vira uma frase na tela, e a
// conexão fica em `attention` para a pessoa saber que precisa reconectar.
const withMeta = async acao => {
  isBusyConnection.value = true;
  connectionError.value = '';
  try {
    await acao();
    await loadConnections();
  } catch (error) {
    connectionError.value = metaRefusalMessage(error);
  } finally {
    isBusyConnection.value = false;
  }
};

const connectMeta = () =>
  withMeta(async () => {
    const { data } = await MarketingAPI.connectionAuthorizationUrl();
    window.location.href = data.url;
  });

const disconnectMeta = id => withMeta(() => MarketingAPI.disconnect(id));

// Pergunta ao Meta o que ele de fato concedeu. Quando o papel na página já
// está certo e a chamada continua sendo recusada, é isto que separa
// "permissão não adicionada ao app" de "caixa desmarcada no consentimento".
const permissionAudit = ref(null);

const checkPermissions = id =>
  withMeta(async () => {
    permissionAudit.value = null;
    const { data } = await MarketingAPI.connectionPermissions(id);
    permissionAudit.value = data;
  });
const syncPages = id => withMeta(() => MarketingAPI.syncPages(id));
const togglePage = (id, pageId, subscribed) =>
  withMeta(() => MarketingAPI.subscribePage(id, pageId, subscribed));
const syncForms = (id, pageId) =>
  withMeta(() => MarketingAPI.syncLeadForms(id, pageId));
const toggleForm = (form, active) =>
  withMeta(() =>
    MarketingAPI.updateLeadForm(form.id, { lead_form: { active } })
  );

const loadIntake = async () => {
  const [sourcesResponse, boardsResponse] = await Promise.all([
    MarketingAPI.getIntakeSources(),
    KanbanBoardsAPI.get(),
  ]);
  intakeSources.value = sourcesResponse.data.payload || [];
  boards.value = boardsResponse.data?.payload || boardsResponse.data || [];
};

const onBoardChosen = async boardId => {
  novaOrigem.value.stage_id = '';
  novaOrigem.value.inbox_id = '';
  boardStages.value = [];
  allowedInboxIds.value = [];
  if (!boardId) return;

  const { data } = await KanbanBoardsAPI.getSettings(boardId);
  boardStages.value = data.stages || [];
  allowedInboxIds.value = data.allowed_inbox_ids || [];
};

const createSource = async () => {
  isSavingSource.value = true;
  intakeError.value = '';
  tokenRevelado.value = '';
  try {
    const { data } = await MarketingAPI.createIntakeSource({
      intake_source: {
        name: novaOrigem.value.name,
        crm_destination: {
          kanban_board_id: novaOrigem.value.board_id,
          kanban_stage_id: novaOrigem.value.stage_id,
          inbox_id: novaOrigem.value.inbox_id,
        },
      },
    });
    tokenRevelado.value = data.token;
    novaOrigem.value = { name: '', board_id: '', stage_id: '', inbox_id: '' };
    await loadIntake();
  } catch (error) {
    intakeError.value =
      error?.response?.data?.message || t('MARKETING.INTAKE.ERROR');
  } finally {
    isSavingSource.value = false;
  }
};

const rotateSource = async id => {
  const { data } = await MarketingAPI.rotateIntakeSource(id);
  tokenRevelado.value = data.token;
  await loadIntake();
};

const deactivateSource = async id => {
  await MarketingAPI.deactivateIntakeSource(id);
  await loadIntake();
};

const loadModule = async () => {
  const { data } = await MarketingAPI.getModule();
  marketingModule.value = data;
};

const loadPanel = async () => {
  if (!isEnabled.value) return;
  isLoadingTouchpoints.value = true;
  try {
    const [summaryResponse, listResponse] = await Promise.all([
      MarketingAPI.getSummary(),
      MarketingAPI.getTouchpoints({ limit: 25 }),
    ]);
    summary.value = summaryResponse.data;
    touchpoints.value = listResponse.data.payload || [];
  } finally {
    isLoadingTouchpoints.value = false;
  }
};

const toggleModule = async enabled => {
  isSavingModule.value = true;
  saveError.value = '';
  try {
    const { data } = await MarketingAPI.updateModule({
      marketing_module: { enabled, confirm_disable: !enabled },
    });
    marketingModule.value = data;
    if (enabled) await loadPanel();
  } catch (error) {
    saveError.value =
      error?.response?.data?.message || t('MARKETING.SETTINGS.SAVE_ERROR');
  } finally {
    isSavingModule.value = false;
  }
};

onMounted(async () => {
  try {
    await loadModule();
    await loadPanel();
    if (isEnabled.value && canConfigure.value) {
      await loadIntake();
      await loadConnections();
    }
  } catch (error) {
    loadError.value =
      error?.response?.data?.message || t('MARKETING.LOAD_ERROR');
  } finally {
    isLoading.value = false;
  }
});
</script>

<template>
  <div class="h-full w-full overflow-auto bg-n-background p-6">
    <div class="mx-auto flex w-full max-w-6xl flex-col gap-6">
      <RaevoPageHeader
        :eyebrow="t('MARKETING.EYEBROW')"
        :title="t('MARKETING.TITLE')"
        :subtitle="t('MARKETING.SUBTITLE')"
      >
        <template #actions>
          <RaevoStamp
            v-if="marketingModule"
            :variant="isEnabled ? 'success' : 'neutral'"
            :label="
              isEnabled
                ? t('MARKETING.STATUS.ENABLED')
                : t('MARKETING.STATUS.DISABLED')
            "
          />
          <button
            v-if="canConfigure"
            type="button"
            data-testid="marketing-toggle-settings"
            class="flex p-0 size-9 items-center justify-center rounded-full border border-solid border-n-weak text-n-slate-11 outline-none hover:bg-n-slate-3 hover:text-n-slate-12 focus-visible:ring-2 focus-visible:ring-n-brand"
            :class="activeView === 'settings' ? 'bg-n-blue-3 text-n-brand' : ''"
            :aria-pressed="activeView === 'settings'"
            :aria-label="
              activeView === 'settings'
                ? t('MARKETING.BACK_TO_PANEL')
                : t('MARKETING.OPEN_SETTINGS')
            "
            :title="
              activeView === 'settings'
                ? t('MARKETING.BACK_TO_PANEL')
                : t('MARKETING.OPEN_SETTINGS')
            "
            @click="
              activeView = activeView === 'settings' ? 'panel' : 'settings'
            "
          >
            <i class="i-lucide-settings size-4" />
          </button>
        </template>
      </RaevoPageHeader>

      <p v-if="loadError" class="mb-0 text-sm text-n-ruby-11" role="alert">
        {{ loadError }}
      </p>

      <div v-else-if="isLoading" class="text-sm text-n-slate-11">
        {{ t('MARKETING.LOADING') }}
      </div>

      <!-- Configurações: ligar o módulo. Conexões e entrada de leads entram aqui. -->
      <section
        v-else-if="activeView === 'settings'"
        class="grid gap-4 rounded-xl border border-n-weak bg-n-solid-1 p-4"
      >
        <h3 class="mb-0 text-sm font-semibold text-n-slate-12">
          {{ t('MARKETING.SETTINGS.TITLE') }}
        </h3>
        <p class="mb-0 text-sm text-n-slate-11">
          {{ t('MARKETING.SETTINGS.DESCRIPTION') }}
        </p>
        <label class="flex items-center gap-2 text-sm text-n-slate-12">
          <input
            :checked="isEnabled"
            :disabled="isSavingModule"
            type="checkbox"
            data-testid="marketing-toggle-module"
            class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
            @change="toggleModule($event.target.checked)"
          />
          {{ t('MARKETING.SETTINGS.ENABLE') }}
        </label>
        <p v-if="saveError" class="mb-0 text-xs text-n-ruby-11" role="alert">
          {{ saveError }}
        </p>
      </section>

      <!--
        Contas de anúncio. Meta primeiro porque é o Lead Ads que precisa dela;
        Google e TikTok chegam com os relatórios de custo, e aparecem
        desabilitados para a ausência ser deliberada e não parecer falta.
      -->
      <section
        v-if="activeView === 'settings' && isEnabled"
        class="grid gap-4 rounded-xl border border-n-weak bg-n-solid-1 p-4"
      >
        <div class="grid gap-1">
          <h3 class="mb-0 text-sm font-semibold text-n-slate-12">
            {{ t('MARKETING.CONNECTIONS.TITLE') }}
          </h3>
          <p class="mb-0 text-sm text-n-slate-11">
            {{ t('MARKETING.CONNECTIONS.DESCRIPTION') }}
          </p>
        </div>

        <div class="grid gap-3 sm:grid-cols-3">
          <div class="grid gap-2 rounded-lg border border-n-weak p-3">
            <span
              class="flex items-center gap-2 text-sm font-medium text-n-slate-12"
            >
              <i class="i-lucide-facebook size-4" />
              {{ metaLabel }}
            </span>
            <template v-if="metaConnection">
              <RaevoStamp
                :variant="
                  metaConnection.status === 'connected' ? 'success' : 'warning'
                "
                :label="
                  metaConnection.display_name ||
                  metaConnection.external_account_id
                "
              />
              <p
                v-if="metaConnection.token_expiring"
                class="mb-0 text-xs text-n-amber-11"
                role="alert"
              >
                {{ t('MARKETING.CONNECTIONS.EXPIRING') }}
              </p>
              <div class="flex flex-wrap gap-2">
                <NextButton
                  :label="t('MARKETING.CONNECTIONS.SYNC_PAGES')"
                  :disabled="isBusyConnection"
                  faded
                  slate
                  sm
                  @click="syncPages(metaConnection.id)"
                />
                <NextButton
                  :label="t('MARKETING.CONNECTIONS.CHECK_PERMISSIONS')"
                  :disabled="isBusyConnection"
                  data-testid="marketing-check-permissions"
                  faded
                  slate
                  sm
                  @click="checkPermissions(metaConnection.id)"
                />
                <NextButton
                  :label="t('MARKETING.CONNECTIONS.DISCONNECT')"
                  :disabled="isBusyConnection"
                  faded
                  ruby
                  sm
                  @click="disconnectMeta(metaConnection.id)"
                />
              </div>
              <p
                v-if="permissionAudit"
                class="mb-0 text-xs"
                :class="
                  permissionAudit.missing.length
                    ? 'text-n-amber-11'
                    : 'text-n-teal-11'
                "
                role="status"
              >
                {{
                  permissionAudit.missing.length
                    ? t('MARKETING.CONNECTIONS.PERMISSIONS_MISSING', {
                        scopes: permissionAudit.missing.join(', '),
                      })
                    : t('MARKETING.CONNECTIONS.PERMISSIONS_OK')
                }}
              </p>
            </template>
            <NextButton
              v-else
              :label="t('MARKETING.CONNECTIONS.CONNECT')"
              :disabled="isBusyConnection"
              data-testid="marketing-connect-meta"
              sm
              @click="connectMeta"
            />
          </div>

          <div
            v-for="platform in soonPlatforms"
            :key="platform"
            class="grid gap-2 rounded-lg border border-dashed border-n-weak p-3 opacity-60"
          >
            <span class="text-sm font-medium text-n-slate-11">{{
              platform
            }}</span>
            <RaevoStamp
              variant="neutral"
              :label="t('MARKETING.CONNECTIONS.SOON')"
            />
          </div>
        </div>

        <!-- Assinar `leadgen` é o que faz o Meta começar a nos avisar. -->
        <div v-if="metaPages.length" class="grid gap-2">
          <h4
            class="mb-0 text-xs font-medium uppercase tracking-[0.16em] text-n-slate-10"
          >
            {{ t('MARKETING.CONNECTIONS.PAGES') }}
          </h4>
          <div
            v-for="page in metaPages"
            :key="page.id"
            class="flex flex-wrap items-center gap-3 border-b border-n-weak py-2 last:border-b-0"
          >
            <span class="min-w-0 flex-1 break-words text-sm text-n-slate-12">
              {{ page.name }}
              <span
                v-if="pageHasLimitedAccess(page)"
                class="block text-xs text-n-slate-11"
              >
                {{ t('MARKETING.CONNECTIONS.PAGE_LIMITED_HINT') }}
              </span>
            </span>
            <RaevoStamp
              v-if="pageHasLimitedAccess(page)"
              variant="warning"
              icon="i-lucide-shield-alert"
              :label="t('MARKETING.CONNECTIONS.PAGE_LIMITED')"
            />
            <NextButton
              :label="
                page.subscribed
                  ? t('MARKETING.CONNECTIONS.UNSUBSCRIBE')
                  : t('MARKETING.CONNECTIONS.SUBSCRIBE')
              "
              :disabled="isBusyConnection"
              faded
              slate
              sm
              @click="togglePage(metaConnection.id, page.id, !page.subscribed)"
            />
            <NextButton
              :label="t('MARKETING.CONNECTIONS.SYNC_FORMS')"
              :disabled="isBusyConnection"
              faded
              slate
              sm
              @click="syncForms(metaConnection.id, page.id)"
            />
          </div>
        </div>

        <div v-if="leadForms.length" class="grid gap-2">
          <h4
            class="mb-0 text-xs font-medium uppercase tracking-[0.16em] text-n-slate-10"
          >
            {{ t('MARKETING.CONNECTIONS.FORMS') }}
          </h4>
          <div
            v-for="form in leadForms"
            :key="form.id"
            class="flex flex-wrap items-center gap-3 border-b border-n-weak py-2 last:border-b-0"
            data-testid="marketing-lead-form-row"
          >
            <span class="min-w-0 flex-1 break-words text-sm text-n-slate-12">
              {{ form.name || form.external_form_id }}
              <span class="text-n-slate-10">· {{ form.page_name }}</span>
            </span>
            <RaevoStamp
              :variant="form.active ? 'success' : 'neutral'"
              :label="
                form.active
                  ? t('MARKETING.CONNECTIONS.FORM_ACTIVE')
                  : t('MARKETING.CONNECTIONS.FORM_INACTIVE')
              "
            />
            <NextButton
              :label="
                form.active
                  ? t('MARKETING.CONNECTIONS.UNSUBSCRIBE')
                  : t('MARKETING.CONNECTIONS.SUBSCRIBE')
              "
              :disabled="isBusyConnection"
              faded
              slate
              sm
              @click="toggleForm(form, !form.active)"
            />
          </div>
        </div>

        <p
          v-if="connectionError"
          class="mb-0 text-xs text-n-ruby-11"
          role="alert"
        >
          {{ connectionError }}
        </p>
      </section>

      <!--
        Entrada de leads: um endereço por origem, para a landing e o n8n
        mandarem lead direto para um quadro. O token é a credencial de uma
        escrita pública — aparece uma vez e desliga na hora.
      -->
      <section
        v-if="activeView === 'settings' && isEnabled"
        class="grid gap-4 rounded-xl border border-n-weak bg-n-solid-1 p-4"
      >
        <div class="grid gap-1">
          <h3 class="mb-0 text-sm font-semibold text-n-slate-12">
            {{ t('MARKETING.INTAKE.TITLE') }}
          </h3>
          <p class="mb-0 text-sm text-n-slate-11">
            {{ t('MARKETING.INTAKE.DESCRIPTION') }}
          </p>
          <p class="mb-0 text-xs text-n-slate-10">
            {{ t('MARKETING.INTAKE.ENDPOINT') }}
            <code class="rounded bg-n-alpha-2 px-1">{{ intakeEndpoint }}</code>
            — {{ t('MARKETING.INTAKE.SCHEMA_HINT') }}
          </p>
        </div>

        <p
          v-if="tokenRevelado"
          class="mb-0 grid gap-1 rounded-lg bg-n-alpha-2 p-3"
          data-testid="marketing-intake-token"
        >
          <span class="text-xs font-medium text-n-slate-11">
            {{ t('MARKETING.INTAKE.TOKEN_ONCE') }}
          </span>
          <code class="break-all text-sm text-n-slate-12">{{
            tokenRevelado
          }}</code>
        </p>

        <ul v-if="intakeSources.length" class="grid list-none gap-1 p-0">
          <li
            v-for="src in intakeSources"
            :key="src.id"
            class="flex flex-wrap items-center gap-3 border-b border-n-weak py-2 last:border-b-0"
          >
            <span class="min-w-0 flex-1 break-words text-sm text-n-slate-12">
              {{ src.name }}
            </span>
            <span class="text-xs tabular-nums text-n-slate-10">
              {{
                t('MARKETING.INTAKE.RECEIVED', { count: src.received_count })
              }}
            </span>
            <button
              type="button"
              class="rounded-full border border-solid border-n-weak px-3 py-1 text-xs text-n-slate-11 outline-none hover:bg-n-alpha-2 focus-visible:ring-2 focus-visible:ring-n-brand"
              @click="rotateSource(src.id)"
            >
              {{ t('MARKETING.INTAKE.ROTATE') }}
            </button>
            <button
              v-if="src.active"
              type="button"
              class="rounded-full border border-solid border-n-weak px-3 py-1 text-xs text-n-ruby-11 outline-none hover:bg-n-alpha-2 focus-visible:ring-2 focus-visible:ring-n-brand"
              @click="deactivateSource(src.id)"
            >
              {{ t('MARKETING.INTAKE.DEACTIVATE') }}
            </button>
          </li>
        </ul>
        <p v-else class="mb-0 text-sm text-n-slate-9">
          {{ t('MARKETING.INTAKE.NONE') }}
        </p>

        <form class="grid gap-3 sm:grid-cols-4" @submit.prevent="createSource">
          <RaevoField :label="t('MARKETING.INTAKE.NAME')">
            <template #default="{ controlClass, fieldId }">
              <input
                :id="fieldId"
                v-model="novaOrigem.name"
                type="text"
                required
                :class="controlClass"
                :placeholder="t('MARKETING.INTAKE.NAME_PLACEHOLDER')"
              />
            </template>
          </RaevoField>
          <RaevoField :label="t('MARKETING.INTAKE.BOARD')" variant="select">
            <template #default="{ controlClass, fieldId }">
              <select
                :id="fieldId"
                v-model="novaOrigem.board_id"
                required
                :class="controlClass"
                @change="onBoardChosen(novaOrigem.board_id)"
              >
                <option value="" />
                <option
                  v-for="board in boards"
                  :key="board.id"
                  :value="board.id"
                >
                  {{ board.name }}
                </option>
              </select>
            </template>
          </RaevoField>
          <RaevoField :label="t('MARKETING.INTAKE.STAGE')" variant="select">
            <template #default="{ controlClass, fieldId }">
              <select
                :id="fieldId"
                v-model="novaOrigem.stage_id"
                required
                :class="controlClass"
              >
                <option value="" />
                <option
                  v-for="stage in boardStages"
                  :key="stage.id"
                  :value="stage.id"
                >
                  {{ stage.name }}
                </option>
              </select>
            </template>
          </RaevoField>
          <RaevoField :label="t('MARKETING.INTAKE.INBOX')" variant="select">
            <template #default="{ controlClass, fieldId }">
              <select
                :id="fieldId"
                v-model="novaOrigem.inbox_id"
                required
                :class="controlClass"
              >
                <option value="" />
                <option
                  v-for="inbox in inboxOptions"
                  :key="inbox.id"
                  :value="inbox.id"
                >
                  {{ inbox.name }}
                </option>
              </select>
            </template>
          </RaevoField>
          <div class="sm:col-span-4">
            <NextButton
              type="submit"
              :label="t('MARKETING.INTAKE.CREATE')"
              :disabled="isSavingSource"
              data-testid="marketing-create-intake-source"
              sm
            />
          </div>
        </form>

        <p v-if="intakeError" class="mb-0 text-xs text-n-ruby-11" role="alert">
          {{ intakeError }}
        </p>
      </section>

      <!-- Módulo desligado: um único caminho à frente, não uma tela vazia. -->
      <section
        v-else-if="!isEnabled"
        class="grid gap-3 rounded-xl border border-n-weak bg-n-solid-1 p-6 text-center"
      >
        <h3 class="mb-0 text-sm font-semibold text-n-slate-12">
          {{ t('MARKETING.EMPTY.DISABLED_TITLE') }}
        </h3>
        <p class="mb-0 text-sm text-n-slate-11">
          {{ t('MARKETING.EMPTY.DISABLED_BODY') }}
        </p>
      </section>

      <template v-else>
        <!--
          A taxa de captação primeiro: antes de prometer ROAS, ela diz se
          estamos conseguindo saber de onde o lead vem.
        -->
        <section class="grid gap-4 sm:grid-cols-3">
          <div class="rounded-xl border border-n-weak bg-n-solid-1 p-4">
            <span
              class="block text-micro font-bold uppercase tracking-[0.16em] text-n-slate-10"
            >
              {{ t('MARKETING.PANEL.CAPTURE_RATE') }}
            </span>
            <strong
              data-testid="marketing-capture-rate"
              class="mt-1 block text-3xl font-bold tabular-nums text-n-slate-12"
            >
              {{ captureRate }}%
            </strong>
            <span class="text-xs text-n-slate-11">
              {{
                t('MARKETING.PANEL.CAPTURE_RATE_HINT', {
                  identified: summary?.identified ?? 0,
                  total: summary?.total ?? 0,
                })
              }}
            </span>
          </div>
          <div
            class="rounded-xl border border-n-weak bg-n-solid-1 p-4 sm:col-span-2"
          >
            <span
              class="block text-micro font-bold uppercase tracking-[0.16em] text-n-slate-10"
            >
              {{ t('MARKETING.PANEL.BY_ORIGIN') }}
            </span>
            <p
              v-if="!originRows.length"
              class="mb-0 mt-2 text-sm text-n-slate-9"
            >
              {{ t('MARKETING.PANEL.NO_DATA') }}
            </p>
            <dl v-else class="mt-2 grid gap-1">
              <div
                v-for="[origin, count] in originRows"
                :key="origin"
                class="grid grid-cols-[minmax(0,10rem)_1fr_auto] items-center gap-3"
              >
                <dt class="min-w-0 break-words text-sm text-n-slate-11">
                  {{ origin }}
                </dt>
                <div class="h-1.5 w-full rounded-full bg-n-alpha-2">
                  <div
                    class="h-full rounded-full bg-n-brand"
                    :style="{ width: shareOf(originRows, count) }"
                  />
                </div>
                <dd
                  class="mb-0 text-sm font-semibold tabular-nums text-n-slate-12"
                >
                  {{ count }}
                </dd>
              </div>
            </dl>
          </div>
        </section>

        <section
          v-if="campaignRows.length"
          class="rounded-xl border border-n-weak bg-n-solid-1 p-4"
        >
          <h3 class="mb-2 text-sm font-semibold text-n-slate-12">
            {{ t('MARKETING.PANEL.TOP_CAMPAIGNS') }}
          </h3>
          <dl class="grid gap-1">
            <div
              v-for="[campaign, count] in campaignRows"
              :key="campaign"
              class="grid grid-cols-[minmax(0,14rem)_1fr_auto] items-center gap-3"
            >
              <dt class="min-w-0 break-words text-sm text-n-slate-11">
                {{ campaign }}
              </dt>
              <div class="h-1.5 w-full rounded-full bg-n-alpha-2">
                <div
                  class="h-full rounded-full bg-n-brand"
                  :style="{ width: shareOf(campaignRows, count) }"
                />
              </div>
              <dd
                class="mb-0 text-sm font-semibold tabular-nums text-n-slate-12"
              >
                {{ count }}
              </dd>
            </div>
          </dl>
        </section>

        <section class="rounded-xl border border-n-weak bg-n-solid-1 p-4">
          <h3 class="mb-2 text-sm font-semibold text-n-slate-12">
            {{ t('MARKETING.PANEL.RECENT') }}
          </h3>
          <p v-if="isLoadingTouchpoints" class="mb-0 text-sm text-n-slate-11">
            {{ t('MARKETING.LOADING') }}
          </p>
          <p
            v-else-if="!touchpoints.length"
            class="mb-0 text-sm text-n-slate-9"
            data-testid="marketing-touchpoints-empty"
          >
            {{ t('MARKETING.PANEL.NO_TOUCHPOINTS') }}
          </p>
          <div v-else class="overflow-x-auto">
            <table
              class="w-full text-left text-sm"
              data-testid="marketing-touchpoints-table"
            >
              <thead>
                <tr class="text-n-slate-10">
                  <th class="py-2 pr-3 font-medium">
                    {{ t('MARKETING.TABLE.WHEN') }}
                  </th>
                  <th class="py-2 pr-3 font-medium">
                    {{ t('MARKETING.TABLE.ORIGIN') }}
                  </th>
                  <th class="py-2 pr-3 font-medium">
                    {{ t('MARKETING.TABLE.CAMPAIGN') }}
                  </th>
                  <th class="py-2 font-medium">
                    {{ t('MARKETING.TABLE.CONTACT') }}
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="touchpoint in touchpoints"
                  :key="touchpoint.id"
                  class="border-t border-n-weak"
                >
                  <td class="py-2 pr-3 tabular-nums text-n-slate-11">
                    {{ formatMoment(touchpoint.occurred_at) }}
                  </td>
                  <td class="py-2 pr-3 text-n-slate-12">
                    {{
                      touchpoint.payload.origem_do_lead ||
                      t('MARKETING.TABLE.UNKNOWN')
                    }}
                  </td>
                  <td class="min-w-0 break-words py-2 pr-3 text-n-slate-11">
                    {{
                      touchpoint.payload.utm_campaign ||
                      t('MARKETING.TABLE.UNKNOWN')
                    }}
                  </td>
                  <td class="py-2">
                    <router-link
                      v-if="touchpoint.contact"
                      :to="contactPath(touchpoint.contact)"
                      class="text-n-brand hover:underline"
                    >
                      {{ touchpoint.contact.name }}
                    </router-link>
                    <span v-else class="text-n-slate-9">
                      {{ t('MARKETING.TABLE.NO_CONTACT') }}
                    </span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>
      </template>
    </div>
  </div>
</template>
