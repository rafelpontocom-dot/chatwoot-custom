<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import RaevoHomeAPI from 'dashboard/api/raevoHome';
import RaevoPageHeader from 'dashboard/components-next/raevo/RaevoPageHeader.vue';
import RaevoStamp from 'dashboard/components-next/raevo/RaevoStamp.vue';

const { t, locale } = useI18n();
const route = useRoute();
const router = useRouter();
const data = ref({
  open_conversations_count: 0,
  open_conversations: [],
  overdue_actions_count: 0,
  overdue_actions_count_capped: false,
  overdue_actions: [],
  today_appointments: null,
  overdue_payments: null,
  stale_opportunities: null,
  filters: { inboxes: [], boards: [] },
});

// O que a secretaria escolhe fica na URL: voltar da conversa devolve a mesma
// lista, e o filtro pode ser partilhado com quem está ao lado.
const inboxId = ref(String(route.query.inbox_id || ''));
const boardId = ref(String(route.query.board_id || ''));
const conversationSort = ref(
  String(route.query.conversation_sort || 'waiting')
);
const actionSort = ref(String(route.query.action_sort || 'overdue'));
const period = ref(String(route.query.period || ''));

// «Tudo» é o valor vazio, não uma opção com semântica própria: sem período, o
// servidor não corta nada.
const PERIODS = ['', 'today', '7d', '30d'];

const inboxOptions = computed(() => data.value.filters?.inboxes || []);
const boardOptions = computed(() => data.value.filters?.boards || []);
const isLoading = ref(true);
const hasError = ref(false);

const openConversations = computed(() => data.value.open_conversations || []);
const overdueActions = computed(() => data.value.overdue_actions || []);

// O total vem do servidor, contado antes do corte. Somar o comprimento da lista
// já cortada escondia tudo o que passasse de oito, e escondia mais quanto pior
// estivesse a operação.
const overdueActionsCount = computed(() =>
  Number(data.value.overdue_actions_count || 0)
);
const overdueActionsLabel = computed(() =>
  data.value.overdue_actions_count_capped
    ? `${overdueActionsCount.value}+`
    : String(overdueActionsCount.value)
);
// `null` quer dizer «módulo não está em uso, não mostrar o cartão». Lista vazia
// quer dizer «está ligado e hoje não há nada», que é informação.
const todayAppointments = computed(() => data.value.today_appointments);
const overduePayments = computed(() => data.value.overdue_payments);
const staleOpportunities = computed(() => data.value.stale_opportunities);

const railLabel = card =>
  card?.count_capped ? `${card.count}+` : String(card?.count ?? 0);

const totalAttention = computed(
  () =>
    Number(data.value.open_conversations_count || 0) + overdueActionsCount.value
);

const loadHome = async () => {
  isLoading.value = true;
  hasError.value = false;

  try {
    const response = await RaevoHomeAPI.get({
      inbox_id: inboxId.value || undefined,
      board_id: boardId.value || undefined,
      conversation_sort: conversationSort.value,
      action_sort: actionSort.value,
      period: period.value || undefined,
    });
    data.value = response.data;
  } catch {
    hasError.value = true;
  } finally {
    isLoading.value = false;
  }
};

const openConversation = conversation => {
  router.push({
    name: 'inbox_conversation',
    params: {
      accountId: route.params.accountId,
      conversation_id: conversation.display_id,
    },
  });
};

const openOpportunity = action => {
  router.push({
    name: 'kanban_board_show',
    params: {
      accountId: route.params.accountId,
      boardId: action.kanban_board_id,
    },
    query: { cardId: action.kanban_card_id },
  });
};

const intlLocale = computed(() =>
  locale.value === 'pt_BR' ? 'pt-BR' : locale.value
);

const formatTime = value =>
  new Intl.DateTimeFormat(intlLocale.value, {
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value));

// A moeda vem de cada cobrança: a clínica pode cobrar em EUR e em BRL.
const formatMoney = (cents, currency) =>
  new Intl.NumberFormat(intlLocale.value, {
    style: 'currency',
    currency: currency || 'BRL',
  }).format((Number(cents) || 0) / 100);

const DAY_IN_MS = 86400000;
const daysSince = value =>
  Math.max(Math.floor((Date.now() - new Date(value).getTime()) / DAY_IN_MS), 0);

const openPayment = payment => {
  if (!payment.kanban_card_id) return;

  openOpportunity(payment);
};

const formatDateTime = value => {
  if (!value) return '';

  return new Intl.DateTimeFormat(intlLocale.value, {
    dateStyle: 'short',
    timeStyle: 'short',
  }).format(new Date(value));
};

// A secretaria precisa saber ha quanto tempo alguem espera, nao a data de hoje
// repetida em todas as linhas. A data absoluta continua no title da linha.
const RELATIVE_STEPS = [
  ['minute', 60],
  ['hour', 60],
  ['day', 24],
];

const formatRelative = value => {
  if (!value) return '';

  const elapsedMs = Date.now() - new Date(value).getTime();
  if (Number.isNaN(elapsedMs)) return '';

  const formatter = new Intl.RelativeTimeFormat(intlLocale.value, {
    numeric: 'auto',
  });

  let amount = Math.round(elapsedMs / 1000);
  let unit = 'second';

  RELATIVE_STEPS.every(([nextUnit, factor]) => {
    if (Math.abs(amount) < factor) return false;
    amount = Math.round(amount / factor);
    unit = nextUnit;
    return true;
  });

  return formatter.format(-amount, unit);
};

const hiddenConversationsCount = computed(() =>
  Math.max(
    Number(data.value.open_conversations_count || 0) -
      openConversations.value.length,
    0
  )
);

const goToAllConversations = () => {
  router.push({
    name: 'home',
    params: { accountId: route.params.accountId },
  });
};

const applyChoice = () => {
  router.replace({
    query: {
      ...route.query,
      inbox_id: inboxId.value || undefined,
      board_id: boardId.value || undefined,
      conversation_sort: conversationSort.value,
      action_sort: actionSort.value,
      period: period.value || undefined,
    },
  });
  loadHome();
};

onMounted(loadHome);
</script>

<template>
  <main class="mx-auto flex w-full max-w-[96rem] flex-col gap-4 p-4 lg:p-6">
    <RaevoPageHeader
      :eyebrow="t('HOME.EYEBROW')"
      :title="t('HOME.TITLE')"
      :badge="String(totalAttention)"
      :subtitle="t('HOME.SUBTITLE')"
    >
      <template #actions>
        <button
          type="button"
          class="inline-flex size-9 items-center justify-center rounded-lg text-n-slate-11 hover:bg-n-alpha-2 focus:outline-none focus:ring-2 focus:ring-n-brand/40"
          :aria-label="t('HOME.REFRESH')"
          :title="t('HOME.REFRESH')"
          @click="loadHome"
        >
          <i class="i-lucide-refresh-cw size-4" aria-hidden="true" />
        </button>
      </template>
    </RaevoPageHeader>

    <div v-if="isLoading" class="grid gap-4 xl:grid-cols-2" aria-busy="true">
      <div
        v-for="item in 2"
        :key="item"
        class="h-72 animate-pulse rounded-xl bg-n-slate-3"
      />
    </div>

    <section
      v-else-if="hasError"
      class="rounded-xl border border-n-weak bg-n-solid-1 p-6 text-center"
    >
      <p class="text-sm text-n-slate-11">{{ t('HOME.LOAD_ERROR') }}</p>
      <button
        type="button"
        class="mt-3 rounded-lg bg-n-brand px-3 py-2 text-sm font-medium text-n-solid-1 focus:outline-none focus:ring-2 focus:ring-n-brand/40"
        @click="loadHome"
      >
        {{ t('HOME.TRY_AGAIN') }}
      </button>
    </section>

    <div v-else class="flex flex-col gap-4">
      <!--
        Caixa, funil e período filtram a PÁGINA, não um cartão. Estarem dentro
        dos cartões dizia o contrário. A ordenação fica em cada cartão, porque
        essa sim é de cada lista.
      -->
      <div
        data-testid="home-filter-bar"
        class="flex flex-wrap items-center gap-2 rounded-xl border border-n-weak bg-n-solid-2 px-3 py-2"
      >
        <span
          class="flex items-center gap-1.5 text-xs font-medium text-n-slate-10"
        >
          <i class="i-lucide-filter size-3.5" aria-hidden="true" />
          {{ t('HOME.FILTERS') }}
        </span>
        <select
          v-model="inboxId"
          data-testid="home-filter-inbox"
          class="reset-base mb-0 h-8 rounded-lg border border-solid border-n-weak bg-n-solid-1 px-2 text-xs text-n-slate-11 max-w-[10rem]"
          :aria-label="t('HOME.FILTER_INBOX')"
          @change="applyChoice"
        >
          <option value="">{{ t('HOME.ALL_INBOXES') }}</option>
          <option
            v-for="inbox in inboxOptions"
            :key="inbox.id"
            :value="String(inbox.id)"
          >
            {{ inbox.name }}
          </option>
        </select>
        <select
          v-model="boardId"
          data-testid="home-filter-board"
          class="reset-base mb-0 h-8 rounded-lg border border-solid border-n-weak bg-n-solid-1 px-2 text-xs text-n-slate-11 max-w-[10rem]"
          :aria-label="t('HOME.FILTER_BOARD')"
          @change="applyChoice"
        >
          <option value="">{{ t('HOME.ALL_BOARDS') }}</option>
          <option
            v-for="board in boardOptions"
            :key="board.id"
            :value="String(board.id)"
          >
            {{ board.name }}
          </option>
        </select>
        <select
          v-model="period"
          data-testid="home-filter-period"
          class="reset-base mb-0 h-8 rounded-lg border border-solid border-n-weak bg-n-solid-1 px-2 text-xs text-n-slate-11"
          :aria-label="t('HOME.FILTER_PERIOD')"
          @change="applyChoice"
        >
          <option v-for="value in PERIODS" :key="value || 'all'" :value="value">
            {{ t(`HOME.PERIOD.${value || 'ALL'}`) }}
          </option>
        </select>
      </div>
      <!--
        A agenda é a única lista com forma de tempo, e é o que a secretaria vê
        primeiro de manhã. Por isso é faixa no topo e não mais um cartão.
      -->
      <section
        v-if="todayAppointments"
        data-testid="home-today-appointments"
        class="overflow-hidden rounded-xl border border-n-weak bg-n-solid-1"
      >
        <div
          class="flex items-center justify-between gap-2 border-b border-n-weak px-4 py-3"
        >
          <div class="flex min-w-0 items-center gap-2">
            <i
              class="i-lucide-calendar size-4 text-n-slate-11"
              aria-hidden="true"
            />
            <h2 class="text-sm font-semibold text-n-slate-12">
              {{ t('HOME.TODAY_APPOINTMENTS') }}
            </h2>
            <RaevoStamp :label="String(todayAppointments.count)" size="sm" />
          </div>
        </div>
        <ul
          v-if="todayAppointments.items.length"
          class="grid divide-y divide-n-weak sm:grid-cols-3 sm:divide-y-0 xl:grid-cols-6"
        >
          <li
            v-for="appointment in todayAppointments.items"
            :key="appointment.id"
            class="flex min-w-0 flex-col gap-0.5 px-4 py-3 sm:border-e sm:border-n-weak"
          >
            <span
              class="text-base font-semibold tabular-nums text-n-slate-12"
              :title="formatDateTime(appointment.starts_at)"
            >
              {{ formatTime(appointment.starts_at) }}
            </span>
            <span class="break-words text-sm text-n-slate-12">
              {{ appointment.procedure_name }}
            </span>
            <span class="break-words text-xs text-n-slate-11">
              {{ appointment.contact_name }}
            </span>
            <span class="text-micro uppercase tracking-wide text-n-slate-10">
              {{
                t(`HOME.APPOINTMENT_STATUS.${appointment.status.toUpperCase()}`)
              }}
            </span>
          </li>
        </ul>
        <p v-else class="px-4 py-6 text-center text-sm text-n-slate-10">
          {{ t('HOME.EMPTY_APPOINTMENTS') }}
        </p>
      </section>

      <div
        class="grid items-start gap-4 xl:grid-cols-[minmax(0,1.7fr)_minmax(0,1fr)]"
      >
        <div class="flex min-w-0 flex-col gap-4">
          <section
            class="overflow-hidden rounded-xl border border-n-weak bg-n-solid-1"
          >
            <div
              class="flex items-center justify-between border-b border-n-weak px-4 py-3"
            >
              <div class="flex min-w-0 items-center gap-2">
                <i
                  class="i-lucide-message-circle size-4 text-n-brand"
                  aria-hidden="true"
                />
                <h2 class="text-sm font-semibold text-n-slate-12">
                  {{ t('HOME.OPEN_CONVERSATIONS') }}
                </h2>
              </div>
              <div class="flex shrink-0 items-center gap-2">
                <select
                  v-model="conversationSort"
                  data-testid="home-sort-conversations"
                  class="reset-base mb-0 h-8 rounded-lg border border-solid border-n-weak bg-n-solid-1 px-2 text-xs text-n-slate-11"
                  :aria-label="t('HOME.SORT_CONVERSATIONS')"
                  @change="applyChoice"
                >
                  <option value="waiting">{{ t('HOME.SORT_WAITING') }}</option>
                  <option value="recent">{{ t('HOME.SORT_RECENT') }}</option>
                </select>
                <RaevoStamp
                  :label="String(data.open_conversations_count || 0)"
                  size="sm"
                />
              </div>
            </div>
            <div v-if="openConversations.length" class="divide-y divide-n-weak">
              <button
                v-for="conversation in openConversations"
                :key="conversation.id"
                type="button"
                class="flex w-full items-center gap-3 px-4 py-3 text-left hover:bg-n-alpha-2 focus:outline-none focus:ring-2 focus:ring-inset focus:ring-n-brand/40"
                @click="openConversation(conversation)"
              >
                <span
                  class="grid size-8 shrink-0 place-items-center rounded-full bg-n-blue-3 text-n-blue-11"
                >
                  <i
                    class="i-lucide-message-circle size-4"
                    aria-hidden="true"
                  />
                </span>
                <span class="min-w-0 flex-1">
                  <span
                    class="block break-words text-sm font-medium text-n-slate-12"
                  >
                    {{ conversation.contact_name || t('HOME.UNKNOWN_CONTACT') }}
                  </span>
                  <span
                    class="mt-0.5 block truncate text-xs text-n-slate-10"
                    :title="conversation.last_message || ''"
                  >
                    {{
                      conversation.last_message ||
                      conversation.inbox_name ||
                      t('HOME.NO_INBOX')
                    }}
                  </span>
                </span>
                <span
                  class="shrink-0 text-xs text-n-slate-10"
                  :title="formatDateTime(conversation.last_activity_at)"
                >
                  {{ formatRelative(conversation.last_activity_at) }}
                </span>
              </button>
              <button
                v-if="hiddenConversationsCount"
                type="button"
                data-testid="home-see-all-conversations"
                class="flex w-full items-center justify-center px-4 py-3 text-sm font-medium text-n-brand hover:bg-n-alpha-2 focus:outline-none focus:ring-2 focus:ring-inset focus:ring-n-brand/40"
                @click="goToAllConversations"
              >
                {{ t('HOME.SEE_ALL', { count: hiddenConversationsCount }) }}
              </button>
            </div>
            <p v-else class="px-4 py-10 text-center text-sm text-n-slate-10">
              {{ t('HOME.EMPTY_CONVERSATIONS') }}
            </p>
          </section>

          <!--
        «Parada» é um sinal mais lento que o resto. Fica na coluna larga, o que
        também equilibra as duas alturas.
      -->
          <section
            v-if="staleOpportunities && staleOpportunities.items.length"
            data-testid="home-stale-opportunities"
            class="overflow-hidden rounded-xl border border-n-weak bg-n-solid-1"
          >
            <div
              class="flex items-center gap-2 border-b border-n-weak px-4 py-3"
            >
              <i
                class="i-lucide-circle-pause size-4 text-n-amber-11"
                aria-hidden="true"
              />
              <h2 class="text-sm font-semibold text-n-slate-12">
                {{ t('HOME.STALE_OPPORTUNITIES') }}
              </h2>
              <RaevoStamp
                variant="warning"
                :label="railLabel(staleOpportunities)"
                size="sm"
              />
            </div>
            <div class="divide-y divide-n-weak">
              <button
                v-for="card in staleOpportunities.items"
                :key="card.kanban_card_id"
                type="button"
                class="flex w-full flex-col gap-0.5 px-4 py-3 text-left hover:bg-n-alpha-2 focus:outline-none focus:ring-2 focus:ring-inset focus:ring-n-brand/40"
                @click="openOpportunity(card)"
              >
                <span class="break-words text-sm font-medium text-n-slate-12">
                  {{ card.subject }}
                </span>
                <span class="break-words text-xs text-n-slate-10">
                  {{
                    t('HOME.STALE_DETAIL', {
                      stage: card.kanban_stage_name,
                      days: daysSince(card.stage_entered_at),
                      limit: card.stale_days,
                    })
                  }}
                </span>
              </button>
            </div>
          </section>
        </div>

        <div class="flex min-w-0 flex-col gap-4">
          <section
            class="overflow-hidden rounded-xl border border-n-weak bg-n-solid-1"
          >
            <div
              class="flex items-center justify-between border-b border-n-weak px-4 py-3"
            >
              <div class="flex min-w-0 items-center gap-2">
                <i
                  class="i-lucide-clock-alert size-4 text-n-ruby-11"
                  aria-hidden="true"
                />
                <h2 class="text-sm font-semibold text-n-slate-12">
                  {{ t('HOME.OVERDUE_ACTIONS') }}
                </h2>
              </div>
              <div class="flex shrink-0 items-center gap-2">
                <select
                  v-model="actionSort"
                  data-testid="home-sort-actions"
                  class="reset-base mb-0 h-8 rounded-lg border border-solid border-n-weak bg-n-solid-1 px-2 text-xs text-n-slate-11"
                  :aria-label="t('HOME.SORT_ACTIONS')"
                  @change="applyChoice"
                >
                  <option value="overdue">{{ t('HOME.SORT_OVERDUE') }}</option>
                  <option value="recent">
                    {{ t('HOME.SORT_ACTION_RECENT') }}
                  </option>
                </select>
                <RaevoStamp
                  variant="danger"
                  :label="overdueActionsLabel"
                  size="sm"
                />
              </div>
            </div>
            <div v-if="overdueActions.length" class="divide-y divide-n-weak">
              <button
                v-for="action in overdueActions"
                :key="action.kanban_card_id"
                type="button"
                class="flex w-full items-center gap-3 px-4 py-3 text-left hover:bg-n-alpha-2 focus:outline-none focus:ring-2 focus:ring-inset focus:ring-n-brand/40"
                @click="openOpportunity(action)"
              >
                <span
                  class="grid size-8 shrink-0 place-items-center rounded-full bg-n-ruby-3 text-n-ruby-11"
                >
                  <i class="i-lucide-clock-alert size-4" aria-hidden="true" />
                </span>
                <span class="min-w-0 flex-1">
                  <span
                    class="block break-words text-sm font-medium text-n-slate-12"
                  >
                    {{ action.subject }}
                  </span>
                  <span
                    class="mt-0.5 block break-words text-xs text-n-slate-10"
                  >
                    {{
                      t('HOME.PIPELINE_STAGE', {
                        pipeline: action.kanban_board_name,
                        stage: action.kanban_stage_name,
                      })
                    }}
                  </span>
                </span>
                <span
                  class="shrink-0 text-xs font-medium text-n-ruby-11"
                  :title="formatDateTime(action.next_action_at)"
                >
                  {{ formatRelative(action.next_action_at) }}
                </span>
              </button>
            </div>
            <p v-else class="px-4 py-10 text-center text-sm text-n-slate-10">
              {{ t('HOME.EMPTY_ACTIONS') }}
            </p>
          </section>

          <!--
        O Financeiro é opt-in por conta e exige permissão para ver cobranças. Sem
        as duas coisas o servidor devolve nil e o cartão não existe — não aparece
        vazio, que seria pior.
      -->
          <section
            v-if="overduePayments && overduePayments.items.length"
            data-testid="home-overdue-payments"
            class="overflow-hidden rounded-xl border border-n-weak bg-n-solid-1"
          >
            <div
              class="flex items-center gap-2 border-b border-n-weak px-4 py-3"
            >
              <i
                class="i-lucide-receipt-text size-4 text-n-ruby-11"
                aria-hidden="true"
              />
              <h2 class="text-sm font-semibold text-n-slate-12">
                {{ t('HOME.OVERDUE_PAYMENTS') }}
              </h2>
              <RaevoStamp
                variant="danger"
                :label="String(overduePayments.count)"
                size="sm"
              />
            </div>
            <div class="divide-y divide-n-weak">
              <button
                v-for="payment in overduePayments.items"
                :key="payment.id"
                type="button"
                class="flex w-full flex-col gap-0.5 px-4 py-3 text-left hover:bg-n-alpha-2 focus:outline-none focus:ring-2 focus:ring-inset focus:ring-n-brand/40 disabled:cursor-default disabled:hover:bg-transparent"
                :disabled="!payment.kanban_card_id"
                :title="
                  payment.kanban_card_id
                    ? undefined
                    : t('HOME.PAYMENT_NO_OPPORTUNITY')
                "
                @click="openPayment(payment)"
              >
                <span class="break-words text-sm font-medium text-n-slate-12">
                  {{ payment.contact_name }}
                </span>
                <span
                  class="text-sm font-semibold tabular-nums text-n-slate-12"
                >
                  {{ formatMoney(payment.amount_cents, payment.currency) }}
                </span>
                <span
                  class="inline-flex items-center gap-1 text-xs font-medium text-n-ruby-11"
                >
                  <i class="i-lucide-clock-alert size-3" aria-hidden="true" />
                  {{
                    t('HOME.PAYMENT_OVERDUE_SINCE', {
                      days: daysSince(payment.due_on),
                    })
                  }}
                </span>
              </button>
            </div>
          </section>
        </div>
      </div>
    </div>
  </main>
</template>
