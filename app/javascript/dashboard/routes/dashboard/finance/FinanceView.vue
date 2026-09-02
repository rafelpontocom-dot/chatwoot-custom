<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import FinanceAPI from 'dashboard/api/finance';
import Button from 'dashboard/components-next/button/Button.vue';
import {
  RAEVO_CONTROL_CLASS,
  RAEVO_SELECT_CLASS,
} from 'dashboard/components-next/raevo/raevoControl';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { frontendURL, conversationUrl } from 'dashboard/helper/URLHelper';
import { REPLY_EDITOR_MODES } from 'dashboard/components/widgets/WootWriter/constants';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import FinancePaymentDialog from './FinancePaymentDialog.vue';
import FinancePaymentDetailsDialog from './FinancePaymentDetailsDialog.vue';
import RaevoStamp from 'dashboard/components-next/raevo/RaevoStamp.vue';
import RaevoPageHeader from 'dashboard/components-next/raevo/RaevoPageHeader.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();
const agents = useMapGetter('agents/getAgents');
const currentAccount = useMapGetter('getCurrentAccount');
// Raevo · Sereno — o Financeiro é uma fila de cobranças, não um painel de
// configuração. Módulo, segurança e conexões saem da tela operacional e vivem
// atrás da engrenagem. Ver docs/raevo-design-system.md §5.
const activeView = ref('panel');
const financeModule = ref(null);
const connections = ref([]);
const payments = ref([]);
const webhookDeliveries = ref([]);
const paymentSummary = ref({ open: [], received: [], overdue: [] });
const paymentDialog = ref(null);
const paymentDetailsDialog = ref(null);
const isLoading = ref(true);
const isLoadingPayments = ref(false);
const isSavingModule = ref(false);
const isSavingConnection = ref(false);
const isCreatingManualConnection = ref(false);
const isVerifyingConnection = ref(false);
const isDisconnectingConnection = ref(false);
const isConfirmingModuleDisable = ref(false);
const retryingWebhookDeliveryId = ref(null);
const isConfirmingDisconnect = ref(false);
const error = ref('');
const paymentsError = ref('');
const asaasApiKey = ref('');
const asaasWebhookToken = ref('');
const asaasEnvironment = ref('sandbox');
const asaasDisplayName = ref('');
const webhookUrlCopied = ref(false);
const copiedPaymentId = ref(null);
const paymentQuery = ref('');
const paymentStatus = ref('');
const paymentOwnerId = ref('');
const paymentDueFrom = ref('');
const paymentDueTo = ref('');
const webhookDeliveriesError = ref('');

const asaasConnection = computed(() =>
  connections.value.find(connection => connection.provider === 'asaas')
);
const manualConnection = computed(() =>
  connections.value.find(connection => connection.provider === 'manual')
);
const isEnabled = computed(() => financeModule.value?.enabled === true);
const isBrazil = computed(() => financeModule.value?.market === 'BR');
const isPortugal = computed(() => financeModule.value?.market === 'PT');
const accountPermissions = computed(
  () => currentAccount.value?.permissions || []
);
const canConfigure = computed(() =>
  ['administrator', 'finance_configure'].some(permission =>
    accountPermissions.value.includes(permission)
  )
);
const canCreatePayments = computed(() =>
  ['administrator', 'agent', 'finance_create'].some(permission =>
    accountPermissions.value.includes(permission)
  )
);
const canManagePayments = computed(() =>
  ['administrator', 'agent', 'finance_manage'].some(permission =>
    accountPermissions.value.includes(permission)
  )
);
const canRefundPayments = computed(() =>
  ['administrator', 'finance_refund'].some(permission =>
    accountPermissions.value.includes(permission)
  )
);
const canCreatePayment = computed(
  () =>
    canCreatePayments.value &&
    connections.value.some(connection => connection.status === 'connected')
);
const paymentFilterParams = computed(() => ({
  ...(paymentQuery.value.trim() ? { query: paymentQuery.value.trim() } : {}),
  ...(paymentStatus.value ? { status: paymentStatus.value } : {}),
  ...(paymentOwnerId.value ? { owner_id: paymentOwnerId.value } : {}),
  ...(paymentDueFrom.value ? { due_from: paymentDueFrom.value } : {}),
  ...(paymentDueTo.value ? { due_to: paymentDueTo.value } : {}),
}));
const hasPaymentFilters = computed(
  () => Object.keys(paymentFilterParams.value).length > 0
);
const hasAsaasCredential = computed(() => asaasApiKey.value.trim().length > 0);
const failedWebhookDeliveries = computed(() =>
  webhookDeliveries.value.filter(
    delivery => delivery.processing_status === 'failed'
  )
);
const asaasWebhookUrl = computed(() => {
  if (!asaasConnection.value) return '';

  return `${window.location.origin}/webhooks/finance/asaas/${asaasConnection.value.id}`;
});
const asaasConnectionStatusLabel = computed(() => {
  if (!asaasConnection.value) return t('FINANCE.CONNECTIONS.NOT_CONNECTED');

  switch (asaasConnection.value.status) {
    case 'pending':
      return t('FINANCE.CONNECTIONS.STATUS.PENDING');
    case 'connected':
      return t('FINANCE.CONNECTIONS.STATUS.CONNECTED');
    case 'attention':
      return t('FINANCE.CONNECTIONS.STATUS.ATTENTION');
    case 'error':
      return t('FINANCE.CONNECTIONS.STATUS.ERROR');
    case 'disconnected':
      return t('FINANCE.CONNECTIONS.STATUS.DISCONNECTED');
    default:
      return t('FINANCE.CONNECTIONS.NOT_CONNECTED');
  }
});

const formatAmount = payment =>
  new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: payment.currency || 'BRL',
  }).format((payment.amount_cents || 0) / 100);

const formatDueDate = dueOn => {
  if (!dueOn) return t('FINANCE.PAYMENTS.NO_DUE_DATE');

  return new Intl.DateTimeFormat('pt-BR').format(new Date(`${dueOn}T12:00:00`));
};

const formatWebhookDeliveryDate = value => {
  if (!value) return t('FINANCE.CONNECTIONS.WEBHOOK_DELIVERIES.NO_DATE');

  return new Intl.DateTimeFormat('pt-BR', {
    dateStyle: 'short',
    timeStyle: 'short',
  }).format(new Date(value));
};

/**
 * O tom e o ícone de cada estado de cobrança.
 *
 * As nove pastilhas desenhavam todas o mesmo cinzento sem ícone: numa lista de
 * cobranças, «vencida» — o único estado que exige ação hoje — não saltava mais
 * do que «recebida». Três tons dizem o que fazer (agir / feito / a decorrer) e
 * o ícone diz o mesmo sem depender de cor, como pede o design system.
 */
const PAYMENT_STATUS_TONES = Object.freeze({
  overdue: { tone: 'ruby', icon: 'i-lucide-alert-triangle' },
  failed: { tone: 'ruby', icon: 'i-lucide-x-circle' },
  chargeback: { tone: 'ruby', icon: 'i-lucide-alert-octagon' },
  received: { tone: 'teal', icon: 'i-lucide-check-circle-2' },
  confirmed: { tone: 'teal', icon: 'i-lucide-check' },
  refunded: { tone: 'amber', icon: 'i-lucide-undo-2' },
  draft: { tone: 'slate', icon: 'i-lucide-file-text' },
  canceled: { tone: 'slate', icon: 'i-lucide-ban' },
  pending: { tone: 'slate', icon: 'i-lucide-clock' },
});

const PAYMENT_TONE_CLASSES = Object.freeze({
  ruby: 'bg-n-ruby-2 text-n-ruby-11',
  teal: 'bg-n-teal-3 text-n-teal-11',
  amber: 'bg-n-amber-2 text-n-amber-11',
  slate: 'bg-n-alpha-2 text-n-slate-11',
});

const paymentStatusTone = status =>
  PAYMENT_STATUS_TONES[status] || PAYMENT_STATUS_TONES.pending;

const paymentStatusClass = status =>
  PAYMENT_TONE_CLASSES[paymentStatusTone(status).tone];

const paymentStatusLabel = status => {
  switch (status) {
    case 'draft':
      return t('FINANCE.PAYMENTS.STATUS.DRAFT');
    case 'confirmed':
      return t('FINANCE.PAYMENTS.STATUS.CONFIRMED');
    case 'received':
      return t('FINANCE.PAYMENTS.STATUS.RECEIVED');
    case 'overdue':
      return t('FINANCE.PAYMENTS.STATUS.OVERDUE');
    case 'refunded':
      return t('FINANCE.PAYMENTS.STATUS.REFUNDED');
    case 'chargeback':
      return t('FINANCE.PAYMENTS.STATUS.CHARGEBACK');
    case 'canceled':
      return t('FINANCE.PAYMENTS.STATUS.CANCELED');
    case 'failed':
      return t('FINANCE.PAYMENTS.STATUS.FAILED');
    default:
      return t('FINANCE.PAYMENTS.STATUS.PENDING');
  }
};

const openPaymentDialog = () => {
  paymentDialog.value?.open();
};

const openPaymentDetails = payment => {
  paymentDetailsDialog.value?.open(payment.id);
};

const canPreparePaymentLinkForConversation = payment =>
  Boolean(payment.invoice_url && payment.kanban_card?.conversation_id);

const preparePaymentLinkForConversation = payment => {
  if (!canPreparePaymentLinkForConversation(payment)) return;

  const conversationId = payment.kanban_card.conversation_id;
  const key = `draft-${conversationId}-${REPLY_EDITOR_MODES.REPLY}`;
  const currentDraft = store.getters['draftMessages/get'](key);
  const message = [currentDraft, payment.invoice_url]
    .filter(Boolean)
    .join('\n');

  store.dispatch('draftMessages/set', { key, message });
  router.push({
    path: frontendURL(
      conversationUrl({ accountId: route.params.accountId, id: conversationId })
    ),
  });
};

const copyPaymentLink = async payment => {
  if (!payment.invoice_url) return;

  await copyTextToClipboard(payment.invoice_url);
  copiedPaymentId.value = payment.id;
  window.setTimeout(() => {
    if (copiedPaymentId.value === payment.id) copiedPaymentId.value = null;
  }, 2000);
};

const updatePayment = updatedPayment => {
  payments.value = payments.value.map(payment =>
    payment.id === updatedPayment.id ? updatedPayment : payment
  );
};

async function loadPaymentSummary() {
  try {
    const { data } = await FinanceAPI.getPaymentsSummary(
      paymentFilterParams.value
    );
    paymentSummary.value = data;
  } catch {
    paymentSummary.value = { open: [], received: [], overdue: [] };
  }
}

const addPayment = payment => {
  payments.value = [payment, ...payments.value];
  loadPaymentSummary();
};

const handlePaymentCanceled = payment => {
  updatePayment(payment);
  loadPaymentSummary();
};

const loadPayments = async () => {
  isLoadingPayments.value = true;
  paymentsError.value = '';

  try {
    const [paymentsResponse] = await Promise.all([
      FinanceAPI.getPayments(paymentFilterParams.value),
      loadPaymentSummary(),
    ]);
    payments.value = paymentsResponse.data;
  } catch (requestError) {
    paymentsError.value =
      requestError.response?.data?.message || t('FINANCE.ERROR.PAYMENTS');
  } finally {
    isLoadingPayments.value = false;
  }
};

const loadWebhookDeliveries = async () => {
  if (!canConfigure.value || !asaasConnection.value) {
    webhookDeliveries.value = [];
    return;
  }

  webhookDeliveriesError.value = '';
  try {
    const { data } = await FinanceAPI.getWebhookDeliveries(
      asaasConnection.value.id
    );
    webhookDeliveries.value = data;
  } catch {
    webhookDeliveriesError.value = t(
      'FINANCE.CONNECTIONS.WEBHOOK_DELIVERIES.LOAD_ERROR'
    );
  }
};

const retryWebhookDelivery = async delivery => {
  if (!asaasConnection.value || delivery.processing_status !== 'failed') return;

  retryingWebhookDeliveryId.value = delivery.id;
  webhookDeliveriesError.value = '';
  try {
    const { data } = await FinanceAPI.retryWebhookDelivery(
      asaasConnection.value.id,
      delivery.id
    );
    webhookDeliveries.value = webhookDeliveries.value.map(item =>
      item.id === data.id ? data : item
    );
    if (data.processing_status !== 'failed') {
      connections.value = connections.value.map(connection =>
        connection.id === asaasConnection.value.id
          ? { ...connection, status: 'connected', last_error: null }
          : connection
      );
    }
  } catch (requestError) {
    webhookDeliveriesError.value =
      requestError.response?.data?.message ||
      t('FINANCE.CONNECTIONS.WEBHOOK_DELIVERIES.RETRY_ERROR');
  } finally {
    retryingWebhookDeliveryId.value = null;
  }
};

const clearPaymentFilters = async () => {
  paymentQuery.value = '';
  paymentStatus.value = '';
  paymentOwnerId.value = '';
  paymentDueFrom.value = '';
  paymentDueTo.value = '';
  await loadPayments();
};

const loadFinance = async () => {
  isLoading.value = true;
  error.value = '';

  try {
    const { data } = await FinanceAPI.getModule();
    financeModule.value = data;

    if (data.enabled) {
      const connectionsResponse = await FinanceAPI.getProviderConnections();
      connections.value = connectionsResponse.data;
      await Promise.all([loadPayments(), loadWebhookDeliveries()]);
    } else {
      connections.value = [];
      payments.value = [];
      webhookDeliveries.value = [];
    }
  } catch (requestError) {
    error.value =
      requestError.response?.data?.message || t('FINANCE.ERROR.LOAD');
  } finally {
    isLoading.value = false;
  }
};

const updateModule = async enabled => {
  if (!enabled && isEnabled.value && !isConfirmingModuleDisable.value) {
    isConfirmingModuleDisable.value = true;
    return;
  }

  isSavingModule.value = true;
  error.value = '';

  try {
    const { data } = await FinanceAPI.updateModule({
      finance_module: {
        enabled,
        market: financeModule.value.market,
        default_payment_provider: enabled && isBrazil.value ? 'asaas' : null,
        lock_version: financeModule.value.lock_version,
        confirm_disable: !enabled,
      },
    });
    financeModule.value = data;
    if (enabled) {
      await loadFinance();
    } else {
      connections.value = [];
      payments.value = [];
      webhookDeliveries.value = [];
    }
  } catch (requestError) {
    error.value =
      requestError.response?.data?.message || t('FINANCE.ERROR.SAVE');
  } finally {
    isSavingModule.value = false;
    isConfirmingModuleDisable.value = false;
  }
};

const saveMarket = async () => {
  isSavingModule.value = true;
  error.value = '';

  try {
    const { data } = await FinanceAPI.updateModule({
      finance_module: {
        enabled: financeModule.value.enabled,
        market: financeModule.value.market,
        default_payment_provider: isBrazil.value ? 'asaas' : null,
        lock_version: financeModule.value.lock_version,
      },
    });
    financeModule.value = data;
    connections.value = [];
  } catch (requestError) {
    error.value =
      requestError.response?.data?.message || t('FINANCE.ERROR.SAVE');
  } finally {
    isSavingModule.value = false;
  }
};

const saveAsaasConnection = async () => {
  if (!hasAsaasCredential.value) return;

  isSavingConnection.value = true;
  error.value = '';
  const payload = {
    provider_connection: {
      provider: 'asaas',
      environment: asaasEnvironment.value,
      api_key: asaasApiKey.value.trim(),
      webhook_token: asaasWebhookToken.value.trim() || undefined,
      display_name: asaasDisplayName.value.trim(),
      lock_version: asaasConnection.value?.lock_version,
    },
  };

  try {
    const response = asaasConnection.value
      ? await FinanceAPI.updateProviderConnection(
          asaasConnection.value.id,
          payload
        )
      : await FinanceAPI.createProviderConnection(payload);
    const savedConnection = response.data;
    connections.value = [
      ...connections.value.filter(
        connection => connection.id !== savedConnection.id
      ),
      savedConnection,
    ];
    asaasApiKey.value = '';
    asaasWebhookToken.value = '';
  } catch (requestError) {
    error.value =
      requestError.response?.data?.message || t('FINANCE.ERROR.CONNECTION');
  } finally {
    isSavingConnection.value = false;
  }
};

const copyAsaasWebhookUrl = async () => {
  await copyTextToClipboard(asaasWebhookUrl.value);
  webhookUrlCopied.value = true;
  window.setTimeout(() => {
    webhookUrlCopied.value = false;
  }, 2000);
};

const verifyAsaasConnection = async () => {
  if (!asaasConnection.value) return;

  isVerifyingConnection.value = true;
  error.value = '';

  try {
    const { data } = await FinanceAPI.verifyProviderConnection(
      asaasConnection.value.id
    );
    connections.value = connections.value.map(connection =>
      connection.id === data.id ? data : connection
    );
  } catch (requestError) {
    error.value =
      requestError.response?.data?.message || t('FINANCE.ERROR.VERIFY');
  } finally {
    isVerifyingConnection.value = false;
  }
};

const disconnectAsaasConnection = async () => {
  if (!asaasConnection.value) return;

  if (!isConfirmingDisconnect.value) {
    isConfirmingDisconnect.value = true;
    return;
  }

  isDisconnectingConnection.value = true;
  error.value = '';

  try {
    await FinanceAPI.deleteProviderConnection(asaasConnection.value.id);
    connections.value = connections.value.filter(
      connection => connection.id !== asaasConnection.value.id
    );
    isConfirmingDisconnect.value = false;
  } catch (requestError) {
    error.value =
      requestError.response?.data?.message || t('FINANCE.ERROR.DISCONNECT');
  } finally {
    isDisconnectingConnection.value = false;
  }
};

const enableManualConnection = async () => {
  if (manualConnection.value) return;

  isCreatingManualConnection.value = true;
  error.value = '';

  try {
    const { data } = await FinanceAPI.createProviderConnection({
      provider_connection: {
        provider: 'manual',
        environment: 'production',
        display_name: t('FINANCE.CONNECTIONS.MANUAL_NAME'),
        status: 'connected',
      },
    });
    connections.value = [...connections.value, data];
  } catch (requestError) {
    error.value =
      requestError.response?.data?.message || t('FINANCE.ERROR.CONNECTION');
  } finally {
    isCreatingManualConnection.value = false;
  }
};

onMounted(loadFinance);
</script>

<template>
  <main
    class="flex h-full w-full min-w-0 flex-1 flex-col overflow-y-auto bg-n-background px-4 py-5 sm:px-6 lg:px-8"
    data-testid="finance-workspace"
  >
    <div class="mx-auto flex w-full max-w-6xl flex-col gap-6">
      <RaevoPageHeader
        :eyebrow="t('FINANCE.EYEBROW')"
        :title="t('FINANCE.TITLE')"
        :subtitle="t('FINANCE.SUBTITLE')"
      >
        <template #actions>
          <RaevoStamp
            v-if="financeModule"
            :variant="isEnabled ? 'success' : 'neutral'"
            :label="
              isEnabled
                ? t('FINANCE.STATUS.ENABLED')
                : t('FINANCE.STATUS.DISABLED')
            "
          />
          <button
            v-if="canConfigure"
            type="button"
            data-testid="finance-toggle-settings"
            class="flex p-0 size-9 items-center justify-center rounded-full border border-solid border-n-weak text-n-slate-11 outline-none hover:bg-n-slate-3 hover:text-n-slate-12 focus-visible:ring-2 focus-visible:ring-n-brand"
            :class="activeView === 'settings' ? 'bg-n-blue-3 text-n-brand' : ''"
            :aria-pressed="activeView === 'settings'"
            :aria-label="
              activeView === 'settings'
                ? t('FINANCE.BACK_TO_PANEL')
                : t('FINANCE.OPEN_SETTINGS')
            "
            :title="
              activeView === 'settings'
                ? t('FINANCE.BACK_TO_PANEL')
                : t('FINANCE.OPEN_SETTINGS')
            "
            @click="
              activeView = activeView === 'settings' ? 'panel' : 'settings'
            "
          >
            <i
              class="size-4"
              :class="
                activeView === 'settings' ? 'i-lucide-x' : 'i-lucide-settings'
              "
            />
          </button>
        </template>
      </RaevoPageHeader>

      <div
        v-if="isLoading"
        class="grid gap-4 lg:grid-cols-[minmax(0,1.3fr)_minmax(18rem,0.7fr)]"
      >
        <div class="h-64 animate-pulse rounded-lg bg-n-alpha-2" />
        <div class="h-64 animate-pulse rounded-lg bg-n-alpha-2" />
      </div>

      <template v-else-if="financeModule">
        <p
          v-if="error"
          class="rounded-md border border-n-ruby-6 bg-n-ruby-3 px-4 py-3 text-sm text-n-ruby-11"
          role="alert"
        >
          {{ error }}
        </p>

        <section
          v-if="activeView === 'settings' && canConfigure"
          class="grid gap-4 lg:grid-cols-[minmax(0,1.3fr)_minmax(18rem,0.7fr)]"
        >
          <article
            class="rounded-lg border border-n-weak bg-n-solid-1 p-5 shadow-sm"
          >
            <div class="flex items-start justify-between gap-4">
              <div>
                <h2 class="text-base font-semibold text-n-slate-12">
                  {{ t('FINANCE.MODULE.TITLE') }}
                </h2>
                <p class="mt-1 text-sm leading-6 text-n-slate-11">
                  {{ t('FINANCE.MODULE.DESCRIPTION') }}
                </p>
              </div>
              <i
                class="i-lucide-landmark size-5 shrink-0 text-n-brand"
                aria-hidden="true"
              />
            </div>

            <div class="mt-6 grid gap-4 sm:grid-cols-2">
              <label
                class="flex flex-col gap-2 text-sm font-medium text-n-slate-12"
                for="finance-market"
              >
                {{ t('FINANCE.MODULE.MARKET') }}
                <select
                  id="finance-market"
                  v-model="financeModule.market"
                  :class="RAEVO_CONTROL_CLASS"
                  :disabled="isSavingModule"
                  data-testid="finance-market"
                  @change="saveMarket"
                >
                  <option value="BR">{{ t('FINANCE.MARKETS.BR') }}</option>
                  <option value="PT">{{ t('FINANCE.MARKETS.PT') }}</option>
                  <option value="OTHER">
                    {{ t('FINANCE.MARKETS.OTHER') }}
                  </option>
                </select>
              </label>
            </div>

            <div
              class="mt-6 flex flex-wrap items-center justify-between gap-3 rounded-md bg-n-alpha-2 p-4"
            >
              <div>
                <p class="text-sm font-medium text-n-slate-12">
                  {{ t('FINANCE.MODULE.ACCESS_TITLE') }}
                </p>
                <p class="mt-1 text-sm text-n-slate-11">
                  {{ t('FINANCE.MODULE.ACCESS_DESCRIPTION') }}
                </p>
              </div>
              <Button
                :label="
                  !isEnabled
                    ? t('FINANCE.MODULE.ENABLE')
                    : isConfirmingModuleDisable
                      ? t('FINANCE.MODULE.CONFIRM_DISABLE')
                      : t('FINANCE.MODULE.DISABLE')
                "
                :variant="isEnabled ? 'outline' : 'solid'"
                :color="
                  isConfirmingModuleDisable
                    ? 'ruby'
                    : isEnabled
                      ? 'slate'
                      : 'blue'
                "
                :is-loading="isSavingModule"
                data-testid="finance-module-toggle"
                @click="updateModule(!isEnabled)"
              />
            </div>
          </article>

          <article
            class="rounded-lg border border-n-weak bg-n-solid-1 p-5 shadow-sm"
          >
            <i
              class="i-lucide-shield-check size-5 text-n-teal-10"
              aria-hidden="true"
            />
            <h2 class="mt-4 text-base font-semibold text-n-slate-12">
              {{ t('FINANCE.SECURITY.TITLE') }}
            </h2>
            <p class="mt-2 text-sm leading-6 text-n-slate-11">
              {{ t('FINANCE.SECURITY.DESCRIPTION') }}
            </p>
          </article>
        </section>

        <section
          v-if="activeView === 'panel' && isEnabled"
          class="rounded-lg border border-n-weak bg-n-solid-1 shadow-sm"
        >
          <div
            class="flex flex-col gap-3 border-b border-n-weak px-5 py-4 sm:flex-row sm:items-center sm:justify-between"
          >
            <div>
              <h2 class="text-base font-semibold text-n-slate-12">
                {{ t('FINANCE.PAYMENTS.TITLE') }}
              </h2>
              <p class="mt-1 text-sm text-n-slate-11">
                {{ t('FINANCE.PAYMENTS.DESCRIPTION') }}
              </p>
            </div>
            <span
              class="w-fit rounded-full bg-n-alpha-2 px-3 py-1 text-xs font-medium text-n-slate-11"
            >
              {{ payments.length }} {{ t('FINANCE.PAYMENTS.COUNT_LABEL') }}
            </span>
            <Button
              v-if="canCreatePayment"
              :label="t('FINANCE.PAYMENTS.CREATE')"
              data-testid="finance-new-payment"
              @click="openPaymentDialog"
            />
          </div>

          <div
            class="grid gap-px border-b border-n-weak bg-n-weak sm:grid-cols-3"
            data-testid="finance-payments-summary"
          >
            <div class="bg-n-solid-1 px-5 py-3">
              <p class="mb-1 text-xs font-medium text-n-slate-10">
                {{ t('FINANCE.PAYMENTS.SUMMARY.OPEN') }}
              </p>
              <p class="mb-0 text-sm font-semibold text-n-slate-12">
                <template v-if="paymentSummary.open?.length">
                  <span
                    v-for="total in paymentSummary.open"
                    :key="total.currency"
                    class="mr-2 last:mr-0"
                  >
                    {{ formatAmount(total) }}
                  </span>
                </template>
                <template v-else>
                  {{ t('FINANCE.PAYMENTS.SUMMARY.EMPTY_VALUE') }}
                </template>
              </p>
            </div>
            <div class="bg-n-solid-1 px-5 py-3">
              <p class="mb-1 text-xs font-medium text-n-slate-10">
                {{ t('FINANCE.PAYMENTS.SUMMARY.RECEIVED') }}
              </p>
              <p class="mb-0 text-sm font-semibold text-n-slate-12">
                <template v-if="paymentSummary.received?.length">
                  <span
                    v-for="total in paymentSummary.received"
                    :key="total.currency"
                    class="mr-2 last:mr-0"
                  >
                    {{ formatAmount(total) }}
                  </span>
                </template>
                <template v-else>
                  {{ t('FINANCE.PAYMENTS.SUMMARY.EMPTY_VALUE') }}
                </template>
              </p>
            </div>
            <div class="bg-n-solid-1 px-5 py-3">
              <p class="mb-1 text-xs font-medium text-n-slate-10">
                {{ t('FINANCE.PAYMENTS.SUMMARY.OVERDUE') }}
              </p>
              <p
                class="mb-0 text-sm font-semibold"
                :class="
                  paymentSummary.overdue?.length
                    ? 'text-n-ruby-11'
                    : 'text-n-slate-11'
                "
              >
                <template v-if="paymentSummary.overdue?.length">
                  <span
                    v-for="total in paymentSummary.overdue"
                    :key="total.currency"
                    class="mr-2 last:mr-0"
                  >
                    {{ formatAmount(total) }}
                  </span>
                </template>
                <template v-else>
                  {{ t('FINANCE.PAYMENTS.SUMMARY.EMPTY_VALUE') }}
                </template>
              </p>
            </div>
          </div>

          <form
            v-if="payments.length > 0 || hasPaymentFilters || isLoadingPayments"
            data-testid="finance-payment-filters"
            class="grid gap-2 border-b border-n-weak px-5 py-3 lg:grid-cols-[minmax(12rem,1fr)_10rem_11rem_auto_auto] lg:items-center"
            @submit.prevent="loadPayments"
          >
            <label class="sr-only" for="finance-payment-search">
              {{ t('FINANCE.PAYMENTS.FILTERS.SEARCH') }}
            </label>
            <input
              id="finance-payment-search"
              v-model="paymentQuery"
              data-testid="finance-payment-search"
              type="search"
              :placeholder="t('FINANCE.PAYMENTS.FILTERS.SEARCH')"
              class="min-w-0"
              :class="RAEVO_CONTROL_CLASS"
            />
            <label class="sr-only" for="finance-payment-status">
              {{ t('FINANCE.PAYMENTS.FILTERS.STATUS') }}
            </label>
            <select
              id="finance-payment-status"
              v-model="paymentStatus"
              data-testid="finance-payment-status-filter"
              :class="RAEVO_SELECT_CLASS"
            >
              <option value="">
                {{ t('FINANCE.PAYMENTS.FILTERS.ALL_STATUSES') }}
              </option>
              <option value="pending">
                {{ t('FINANCE.PAYMENTS.STATUS.PENDING') }}
              </option>
              <option value="confirmed">
                {{ t('FINANCE.PAYMENTS.STATUS.CONFIRMED') }}
              </option>
              <option value="received">
                {{ t('FINANCE.PAYMENTS.STATUS.RECEIVED') }}
              </option>
              <option value="overdue">
                {{ t('FINANCE.PAYMENTS.STATUS.OVERDUE') }}
              </option>
              <option value="refunded">
                {{ t('FINANCE.PAYMENTS.STATUS.REFUNDED') }}
              </option>
            </select>
            <label class="sr-only" for="finance-payment-owner">
              {{ t('FINANCE.PAYMENTS.FILTERS.OWNER') }}
            </label>
            <select
              id="finance-payment-owner"
              v-model="paymentOwnerId"
              data-testid="finance-payment-owner-filter"
              :class="RAEVO_SELECT_CLASS"
            >
              <option value="">
                {{ t('FINANCE.PAYMENTS.FILTERS.ALL_OWNERS') }}
              </option>
              <option v-for="agent in agents" :key="agent.id" :value="agent.id">
                {{ agent.name }}
              </option>
            </select>
            <label class="sr-only" for="finance-payment-due-from">
              {{ t('FINANCE.PAYMENTS.FILTERS.DUE_FROM') }}
            </label>
            <input
              id="finance-payment-due-from"
              v-model="paymentDueFrom"
              data-testid="finance-payment-due-from"
              type="date"
              :class="RAEVO_CONTROL_CLASS"
            />
            <Button
              type="submit"
              sm
              :label="t('FINANCE.PAYMENTS.FILTERS.APPLY')"
              :is-loading="isLoadingPayments"
            />
            <button
              v-if="hasPaymentFilters"
              type="button"
              data-testid="finance-payment-clear-filters"
              class="h-9 px-2 text-sm font-medium text-n-slate-11 outline-none hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40"
              @click="clearPaymentFilters"
            >
              {{ t('FINANCE.PAYMENTS.FILTERS.CLEAR') }}
            </button>
          </form>

          <p v-if="isLoadingPayments" class="px-5 py-8 text-sm text-n-slate-11">
            {{ t('FINANCE.PAYMENTS.FILTERS.LOADING') }}
          </p>
          <p
            v-else-if="paymentsError"
            class="px-5 py-8 text-sm text-n-ruby-11"
            role="alert"
          >
            {{ paymentsError }}
          </p>
          <!--
            Estado vazio no centro do corpo, não como um parágrafo no topo dele.
            Quando não há conexão de pagamento o botão de criar some por regra —
            então a tela precisa dizer por quê, em vez de deixar a ausência falar.
          -->
          <div
            v-else-if="payments.length === 0"
            data-testid="finance-payments-empty"
            class="flex min-h-64 flex-col items-center justify-center gap-2 px-5 py-12 text-center"
          >
            <i
              aria-hidden="true"
              class="i-lucide-receipt size-6 text-n-slate-10"
            />
            <p class="mb-0 text-sm font-medium text-n-slate-12">
              {{
                hasPaymentFilters
                  ? t('FINANCE.PAYMENTS.FILTERS.EMPTY')
                  : t('FINANCE.PAYMENTS.EMPTY')
              }}
            </p>
            <p
              v-if="
                !hasPaymentFilters && !canCreatePayment && canCreatePayments
              "
              data-testid="finance-no-connection-hint"
              class="mb-0 max-w-md text-sm text-n-slate-11"
            >
              {{ t('FINANCE.PAYMENTS.NEEDS_CONNECTION') }}
            </p>
            <Button
              v-if="!hasPaymentFilters && !canCreatePayment && canConfigure"
              variant="link"
              :label="t('FINANCE.PAYMENTS.GO_TO_CONNECTIONS')"
              data-testid="finance-empty-go-to-connections"
              @click="activeView = 'settings'"
            />
          </div>

          <div
            v-else
            class="divide-y divide-n-weak"
            data-testid="finance-payments-list"
          >
            <article
              v-for="payment in payments"
              :key="payment.id"
              class="grid gap-2 px-5 py-4 sm:grid-cols-[minmax(0,1fr)_minmax(0,1fr)_auto_auto_auto] sm:items-center sm:gap-6"
            >
              <div class="min-w-0">
                <p class="truncate text-sm font-medium text-n-slate-12">
                  {{
                    payment.contact?.name ||
                    t('FINANCE.PAYMENTS.UNKNOWN_CONTACT')
                  }}
                </p>
                <p class="mt-1 text-xs text-n-slate-10">
                  {{ formatDueDate(payment.due_on) }}
                </p>
              </div>
              <div class="min-w-0">
                <p class="truncate text-sm text-n-slate-12">
                  {{
                    payment.kanban_card?.subject ||
                    t('FINANCE.PAYMENTS.NO_OPPORTUNITY')
                  }}
                </p>
                <p class="mt-1 truncate text-xs text-n-slate-10">
                  {{
                    payment.kanban_card?.owner?.name ||
                    t('FINANCE.PAYMENTS.NO_OWNER')
                  }}
                </p>
              </div>
              <span class="text-sm font-semibold text-n-slate-12">
                {{ formatAmount(payment) }}
              </span>
              <span
                class="flex w-fit items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-medium"
                :class="paymentStatusClass(payment.status)"
              >
                <i
                  class="size-3.5 shrink-0"
                  :class="paymentStatusTone(payment.status).icon"
                  aria-hidden="true"
                />
                {{ paymentStatusLabel(payment.status) }}
              </span>
              <div class="flex items-center justify-end gap-1">
                <a
                  v-if="payment.invoice_url"
                  :href="payment.invoice_url"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="w-fit text-sm font-medium text-n-brand outline-none hover:underline focus:ring-2 focus:ring-n-brand/40"
                  data-testid="finance-payment-link"
                >
                  {{ t('FINANCE.PAYMENTS.OPEN_LINK') }}
                </a>
                <button
                  v-if="payment.invoice_url"
                  type="button"
                  data-testid="finance-payment-copy-link"
                  class="flex p-0 size-8 items-center justify-center rounded-md text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40"
                  :aria-label="
                    copiedPaymentId === payment.id
                      ? t('FINANCE.PAYMENTS.COPIED')
                      : t('FINANCE.PAYMENTS.COPY_LINK')
                  "
                  :title="
                    copiedPaymentId === payment.id
                      ? t('FINANCE.PAYMENTS.COPIED')
                      : t('FINANCE.PAYMENTS.COPY_LINK')
                  "
                  @click="copyPaymentLink(payment)"
                >
                  <i
                    :class="
                      copiedPaymentId === payment.id
                        ? 'i-lucide-check'
                        : 'i-lucide-copy'
                    "
                    class="size-4"
                    aria-hidden="true"
                  />
                </button>
                <button
                  v-if="canPreparePaymentLinkForConversation(payment)"
                  type="button"
                  data-testid="finance-payment-send-link"
                  class="flex p-0 size-8 items-center justify-center rounded-md text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40"
                  :aria-label="t('FINANCE.PAYMENTS.SEND_TO_CONVERSATION')"
                  :title="t('FINANCE.PAYMENTS.SEND_TO_CONVERSATION')"
                  @click="preparePaymentLinkForConversation(payment)"
                >
                  <i class="i-lucide-send size-4" />
                </button>
                <button
                  type="button"
                  data-testid="finance-payment-details"
                  class="flex p-0 size-8 items-center justify-center rounded-md text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40"
                  :aria-label="t('FINANCE.PAYMENTS.DETAIL.OPEN')"
                  :title="t('FINANCE.PAYMENTS.DETAIL.OPEN')"
                  @click="openPaymentDetails(payment)"
                >
                  <i class="i-lucide-history size-4" />
                </button>
              </div>
            </article>
          </div>
        </section>

        <FinancePaymentDialog
          ref="paymentDialog"
          :connections="connections"
          :market="financeModule.market"
          @created="addPayment"
        />
        <FinancePaymentDetailsDialog
          ref="paymentDetailsDialog"
          :can-manage="canManagePayments"
          :can-refund="canRefundPayments"
          @canceled="handlePaymentCanceled"
          @received="handlePaymentCanceled"
          @refund-requested="handlePaymentCanceled"
        />

        <section
          v-if="activeView === 'settings' && isEnabled && canConfigure"
          class="rounded-lg border border-n-weak bg-n-solid-1 p-5 shadow-sm"
        >
          <div class="flex items-start justify-between gap-4">
            <div>
              <p class="text-sm font-medium text-n-brand">
                {{ t('FINANCE.CONNECTIONS.EYEBROW') }}
              </p>
              <h2 class="mt-1 text-lg font-semibold text-n-slate-12">
                {{ t('FINANCE.CONNECTIONS.TITLE') }}
              </h2>
            </div>
            <span
              class="rounded-full bg-n-alpha-2 px-3 py-1 text-xs font-medium text-n-slate-11"
            >
              {{
                isBrazil
                  ? t('FINANCE.CONNECTIONS.ASAAS')
                  : t('FINANCE.CONNECTIONS.COMING_SOON')
              }}
            </span>
          </div>

          <div
            v-if="isBrazil"
            class="mt-5 grid gap-5 lg:grid-cols-[minmax(0,1fr)_minmax(0,0.8fr)]"
          >
            <div class="rounded-md border border-n-weak bg-n-alpha-1 p-4">
              <div class="flex items-center gap-3">
                <span
                  class="flex size-9 items-center justify-center rounded-md bg-n-brand/10 text-n-brand"
                >
                  <i class="i-lucide-credit-card size-4" aria-hidden="true" />
                </span>
                <div>
                  <p class="text-sm font-semibold text-n-slate-12">
                    {{ t('FINANCE.CONNECTIONS.PROVIDER_NAME') }}
                  </p>
                  <p class="text-sm text-n-slate-11">
                    {{ asaasConnectionStatusLabel }}
                  </p>
                </div>
              </div>
              <p class="mt-4 text-sm leading-6 text-n-slate-11">
                {{ t('FINANCE.CONNECTIONS.ASAAS_DESCRIPTION') }}
              </p>
              <p
                v-if="asaasConnection?.status === 'attention'"
                class="mt-4 rounded-md bg-n-ruby-3 px-3 py-2 text-sm leading-5 text-n-ruby-11"
                role="alert"
                data-testid="finance-asaas-webhook-attention"
              >
                {{ t('FINANCE.CONNECTIONS.WEBHOOK_ATTENTION') }}
              </p>
              <div
                v-if="asaasConnection?.status === 'attention'"
                class="mt-4 grid gap-2"
                data-testid="finance-webhook-deliveries"
              >
                <p class="mb-0 text-xs font-medium text-n-slate-11">
                  {{ t('FINANCE.CONNECTIONS.WEBHOOK_DELIVERIES.TITLE') }}
                </p>
                <p
                  v-if="webhookDeliveriesError"
                  class="mb-0 text-xs text-n-ruby-11"
                  role="alert"
                >
                  {{ webhookDeliveriesError }}
                </p>
                <p
                  v-else-if="failedWebhookDeliveries.length === 0"
                  class="mb-0 text-xs text-n-slate-10"
                >
                  {{ t('FINANCE.CONNECTIONS.WEBHOOK_DELIVERIES.EMPTY') }}
                </p>
                <article
                  v-for="delivery in failedWebhookDeliveries"
                  :key="delivery.id"
                  class="flex items-center justify-between gap-2 rounded-md bg-n-solid-1 px-3 py-2"
                >
                  <div class="min-w-0">
                    <p class="mb-0 text-xs text-n-slate-12">
                      {{ formatWebhookDeliveryDate(delivery.received_at) }}
                    </p>
                    <p class="mb-0 truncate text-xs text-n-slate-10">
                      {{ delivery.error_message }}
                    </p>
                  </div>
                  <Button
                    :label="t('FINANCE.CONNECTIONS.WEBHOOK_DELIVERIES.RETRY')"
                    color="slate"
                    variant="outline"
                    size="sm"
                    :is-loading="retryingWebhookDeliveryId === delivery.id"
                    :disabled="retryingWebhookDeliveryId !== null"
                    :data-testid="`finance-webhook-delivery-retry-${delivery.id}`"
                    @click="retryWebhookDelivery(delivery)"
                  />
                </article>
              </div>
            </div>

            <form class="grid gap-3" @submit.prevent="saveAsaasConnection">
              <label
                class="grid gap-1.5 text-sm font-medium text-n-slate-12"
                for="finance-asaas-name"
              >
                {{ t('FINANCE.CONNECTIONS.NAME') }}
                <input
                  id="finance-asaas-name"
                  v-model="asaasDisplayName"
                  :class="RAEVO_CONTROL_CLASS"
                  :placeholder="t('FINANCE.CONNECTIONS.NAME_PLACEHOLDER')"
                />
              </label>
              <label
                class="grid gap-1.5 text-sm font-medium text-n-slate-12"
                for="finance-asaas-environment"
              >
                {{ t('FINANCE.CONNECTIONS.ENVIRONMENT') }}
                <select
                  id="finance-asaas-environment"
                  v-model="asaasEnvironment"
                  :class="RAEVO_CONTROL_CLASS"
                >
                  <option value="sandbox">
                    {{ t('FINANCE.CONNECTIONS.SANDBOX') }}
                  </option>
                  <option value="production">
                    {{ t('FINANCE.CONNECTIONS.PRODUCTION') }}
                  </option>
                </select>
              </label>
              <label
                class="grid gap-1.5 text-sm font-medium text-n-slate-12"
                for="finance-asaas-api-key"
              >
                {{ t('FINANCE.CONNECTIONS.API_KEY') }}
                <input
                  id="finance-asaas-api-key"
                  v-model="asaasApiKey"
                  :class="RAEVO_CONTROL_CLASS"
                  type="password"
                  autocomplete="off"
                  :placeholder="t('FINANCE.CONNECTIONS.API_KEY_PLACEHOLDER')"
                  data-testid="finance-asaas-api-key"
                />
              </label>
              <label
                class="grid gap-1.5 text-sm font-medium text-n-slate-12"
                for="finance-asaas-webhook-token"
              >
                {{ t('FINANCE.CONNECTIONS.WEBHOOK_TOKEN') }}
                <input
                  id="finance-asaas-webhook-token"
                  v-model="asaasWebhookToken"
                  :class="RAEVO_CONTROL_CLASS"
                  type="password"
                  autocomplete="off"
                  :placeholder="
                    t('FINANCE.CONNECTIONS.WEBHOOK_TOKEN_PLACEHOLDER')
                  "
                />
                <span class="text-xs font-normal leading-5 text-n-slate-10">
                  {{ t('FINANCE.CONNECTIONS.WEBHOOK_TOKEN_HINT') }}
                </span>
              </label>
              <Button
                class="mt-1 w-full"
                :label="t('FINANCE.CONNECTIONS.SAVE')"
                :disabled="!hasAsaasCredential"
                :is-loading="isSavingConnection"
                type="submit"
                data-testid="finance-asaas-save"
              />
              <Button
                v-if="asaasConnection"
                :label="t('FINANCE.CONNECTIONS.VERIFY')"
                color="slate"
                variant="outline"
                :is-loading="isVerifyingConnection"
                type="button"
                data-testid="finance-asaas-verify"
                @click="verifyAsaasConnection"
              />
              <Button
                v-if="asaasConnection"
                :label="
                  isConfirmingDisconnect
                    ? t('FINANCE.CONNECTIONS.CONFIRM_DISCONNECT')
                    : t('FINANCE.CONNECTIONS.DISCONNECT')
                "
                color="ruby"
                variant="outline"
                :is-loading="isDisconnectingConnection"
                type="button"
                data-testid="finance-asaas-disconnect"
                @click="disconnectAsaasConnection"
              />
            </form>
          </div>
          <div
            v-if="isBrazil && asaasConnection"
            class="mt-5 flex flex-col gap-3 rounded-md border border-n-weak bg-n-alpha-1 p-4 sm:flex-row sm:items-end"
          >
            <label
              class="grid min-w-0 flex-1 gap-1.5 text-sm font-medium text-n-slate-12"
            >
              {{ t('FINANCE.CONNECTIONS.WEBHOOK_URL') }}
              <input
                :value="asaasWebhookUrl"
                class="h-10 w-full truncate rounded-md border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-11"
                readonly
              />
            </label>
            <Button
              :label="
                webhookUrlCopied
                  ? t('FINANCE.CONNECTIONS.COPIED')
                  : t('FINANCE.CONNECTIONS.COPY_URL')
              "
              color="slate"
              variant="outline"
              type="button"
              @click="copyAsaasWebhookUrl"
            />
          </div>
          <div
            v-else-if="isPortugal"
            class="mt-5 flex flex-col gap-4 rounded-md border border-n-weak bg-n-alpha-1 p-4 sm:flex-row sm:items-center sm:justify-between"
          >
            <div>
              <p class="text-sm font-semibold text-n-slate-12">
                {{ t('FINANCE.CONNECTIONS.MANUAL_TITLE') }}
              </p>
              <p class="mt-1 text-sm leading-6 text-n-slate-11">
                {{
                  manualConnection
                    ? t('FINANCE.CONNECTIONS.MANUAL_CONNECTED')
                    : t('FINANCE.CONNECTIONS.MANUAL_DESCRIPTION')
                }}
              </p>
            </div>
            <Button
              v-if="!manualConnection"
              :label="t('FINANCE.CONNECTIONS.MANUAL_ENABLE')"
              :is-loading="isCreatingManualConnection"
              data-testid="finance-manual-enable"
              @click="enableManualConnection"
            />
          </div>
          <p
            v-else
            class="mt-5 rounded-md bg-n-alpha-2 px-4 py-3 text-sm text-n-slate-11"
          >
            {{ t('FINANCE.CONNECTIONS.PT_NOTICE') }}
          </p>
        </section>
      </template>
    </div>
  </main>
</template>
