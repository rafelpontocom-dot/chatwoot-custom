<script setup>
import { computed, nextTick, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import RaevoHomeAPI from 'dashboard/api/raevoHome';
import RaevoPageHeader from 'dashboard/components-next/raevo/RaevoPageHeader.vue';
import RaevoKpiCard from 'dashboard/components-next/raevo/RaevoKpiCard.vue';
import RaevoStamp from 'dashboard/components-next/raevo/RaevoStamp.vue';
import RaevoHomeGrid from 'dashboard/components-next/raevo/home/RaevoHomeGrid.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useAlert } from 'dashboard/composables';
import {
  HOME_WIDGETS,
  INSIGHT_IDS,
  addItem,
  layoutToSave,
  removeItem,
  renameItem,
  resolveLayout,
  visibleLayout,
} from 'dashboard/components-next/raevo/home/raevoHomeLayout';

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

// --- Os quatro indicadores do sistema aprovado -------------------------------
// A fila que abre a tela. Cada número aqui é servido pelo `RaevoHomeController`;
// nenhum é derivado da lista cortada, que mostra oito e esconderia o resto.
//
// **Nenhum cartão tem variação.** O artefacto desenha setas de mês a mês e o
// servidor desta tela não guarda histórico nenhum — só o estado de agora. Um
// delta inventado aqui seria pior do que a ausência dele, porque parece
// informação. As setas entram quando o backend souber comparar.
//
// O rodapé de «Conversas» e de «Ações» diz o PERÍODO, que é o que o número
// realmente cobre: as duas listas são limitadas pelo filtro no topo, e sem isto
// o número não diz de quando é.
// A mesma forma que o `<option>` do filtro de período já usa, mais abaixo neste
// ficheiro. Uma segunda mecânica para o mesmo rótulo divergiria no dia em que
// alguém acrescentasse um período.
const periodLabel = computed(() => t(`HOME.PERIOD.${period.value || 'ALL'}`));

const nextAppointmentFooter = computed(() => {
  const items = todayAppointments.value?.items || [];
  if (!items.length) return t('HOME.KPI_NOTHING_TODAY');
  // `items` vem sempre ordenado por `starts_at` no servidor, não pelo filtro de
  // ordenação — por isso o primeiro é de facto o próximo.
  return t('HOME.KPI_NEXT_AT', {
    time: new Date(items[0].starts_at).toLocaleTimeString(undefined, {
      hour: '2-digit',
      minute: '2-digit',
    }),
  });
});

const overduePaymentsTotal = computed(() => {
  const card = overduePayments.value;
  if (!card) return null;
  const items = card.items || [];
  if (!items.length) return null;
  const cents = items.reduce(
    (soma, payment) => soma + Number(payment.amount_cents || 0),
    0
  );
  return new Intl.NumberFormat(undefined, {
    style: 'currency',
    currency: items[0].currency || 'BRL',
  }).format(cents / 100);
});

const homeIndicators = computed(() => {
  const cards = [
    {
      widget: 'kpi-conversations',
      chave: 'conversations',
      label: t('HOME.OPEN_CONVERSATIONS'),
      value: String(data.value.open_conversations_count ?? 0),
      footer: periodLabel.value,
    },
    {
      widget: 'kpi-actions',
      chave: 'actions',
      label: t('HOME.OVERDUE_ACTIONS'),
      value: overdueActionsLabel.value,
      footer: periodLabel.value,
    },
  ];

  // Agenda e Financeiro são opt-in: `null` quer dizer «módulo não está em uso».
  // O cartão não aparece, em vez de mostrar zero e sugerir que está vazio.
  if (todayAppointments.value) {
    cards.push({
      widget: 'kpi-agenda',
      chave: 'agenda',
      label: t('HOME.TODAY_APPOINTMENTS'),
      value: String(todayAppointments.value.count ?? 0),
      footer: nextAppointmentFooter.value,
    });
  }
  if (overduePayments.value) {
    cards.push({
      widget: 'kpi-payments',
      chave: 'overdue-payments',
      label: t('HOME.OVERDUE_PAYMENTS'),
      value: overduePaymentsTotal.value,
      footer: t('HOME.KPI_CHARGES', {
        count: overduePayments.value.count ?? 0,
      }),
    });
  }

  return cards;
});

// --- O Início editável (proposta A, 18/10) -----------------------------------
// Cada pessoa arruma o seu. O layout grava-se em `ui_settings`, por conta; quem
// nunca arrumou vê o da equipa, se um administrador o definiu, e senão o de
// origem. A geometria toda está em `raevoHomeLayout.js`.
const { uiSettings, updateUISettings } = useUISettings();
const accountKey = computed(() => String(route.params.accountId));
const savedLayouts = computed(() => uiSettings.value?.raevo_home_layout || {});
const teamLayout = computed(() => data.value.layout?.team || null);
const canSetTeam = computed(() => Boolean(data.value.layout?.can_set_team));
const baseLayout = computed(() =>
  resolveLayout({
    user: savedLayouts.value[accountKey.value],
    account: teamLayout.value,
  })
);

// Um bloco só existe se o módulo dele está em uso: `null` do servidor quer
// dizer «não mostrar». Sai do Início e do catálogo, e volta quando o acesso
// voltar — o lugar dele fica gravado.
const insightsAvailable = computed(() => data.value.layout?.insights || []);
const availableIds = computed(() =>
  Object.keys(HOME_WIDGETS).filter(id => {
    if (HOME_WIDGETS[id].insight) return insightsAvailable.value.includes(id);
    if (id === 'kpi-agenda' || id === 'today-appointments') {
      return Boolean(todayAppointments.value);
    }
    if (id === 'kpi-payments' || id === 'overdue-payments') {
      return Boolean(overduePayments.value);
    }
    if (id === 'stale-opportunities') return Boolean(staleOpportunities.value);
    return true;
  })
);

const widgetLabels = computed(() => ({
  'kpi-conversations': t('HOME.OPEN_CONVERSATIONS'),
  'kpi-actions': t('HOME.OVERDUE_ACTIONS'),
  'kpi-agenda': t('HOME.TODAY_APPOINTMENTS'),
  'kpi-payments': t('HOME.OVERDUE_PAYMENTS'),
  'today-appointments': t('HOME.TODAY_APPOINTMENTS'),
  'open-conversations': t('HOME.OPEN_CONVERSATIONS'),
  'overdue-actions': t('HOME.OVERDUE_ACTIONS'),
  'overdue-payments': t('HOME.OVERDUE_PAYMENTS'),
  'stale-opportunities': t('HOME.STALE_OPPORTUNITIES'),
  'kpi-pipeline-value': t('HOME.INSIGHTS.PIPELINE_VALUE'),
  'kpi-close-rate': t('HOME.INSIGHTS.CLOSE_RATE'),
  'kpi-won-month': t('HOME.INSIGHTS.WON_MONTH'),
  'kpi-first-response': t('HOME.INSIGHTS.FIRST_RESPONSE'),
  'kpi-attendance': t('HOME.INSIGHTS.ATTENDANCE'),
  'kpi-ai-opportunities': t('HOME.INSIGHTS.AI_OPPORTUNITIES'),
  'kpi-waiting-24h': t('HOME.INSIGHTS.WAITING_24H'),
}));

const editing = ref(false);
const draft = ref([]);
// «Restaurar padrão» volta a seguir o Início da equipa: ao concluir, o layout
// da pessoa apaga-se em vez de gravar uma cópia que deixaria de acompanhar.
const followDefault = ref(false);
const applyToTeam = ref(false);
const lastRemoved = ref(null);
const isSaving = ref(false);
const catalogDialog = ref(null);
const resetDialog = ref(null);

const shownLayout = computed(() =>
  editing.value
    ? draft.value
    : visibleLayout(baseLayout.value, availableIds.value)
);

// Os insights só se calculam se estiverem no Início de quem abre a tela: quem
// não os pôs não paga as consultas. Acrescentar um pelo «+» pede só esse.
const insights = ref({});
const loadInsights = async ({ reset = false } = {}) => {
  if (reset) insights.value = {};
  const keys = shownLayout.value
    .map(item => item.id)
    .filter(id => INSIGHT_IDS.includes(id) && !(id in insights.value));
  if (!keys.length) return;
  try {
    const response = await RaevoHomeAPI.getInsights({
      keys,
      inbox_id: inboxId.value || undefined,
      board_id: boardId.value || undefined,
    });
    insights.value = { ...insights.value, ...response.data.insights };
  } catch {
    // Sem o número o cartão mostra o travessão; o resto do Início não depende dele.
  }
};
watch(
  () => shownLayout.value.map(item => item.id).join(),
  () => loadInsights()
);

const catalog = computed(() =>
  availableIds.value
    .filter(id => !draft.value.some(item => item.id === id))
    .map(id => ({
      id,
      label: widgetLabels.value[id],
      kind: t(`HOME.LAYOUT.KIND.${HOME_WIDGETS[id].kind}`),
    }))
);

const startEditing = () => {
  draft.value = visibleLayout(baseLayout.value, availableIds.value);
  followDefault.value = false;
  applyToTeam.value = false;
  lastRemoved.value = null;
  editing.value = true;
};

const stopEditing = () => {
  editing.value = false;
  lastRemoved.value = null;
};

// Qualquer mudança depois de uma remoção tira o «Desfazer»: desfazer agora
// repunha um estado anterior e deitava fora o que se fez entretanto.
const changeLayout = items => {
  draft.value = items;
  followDefault.value = false;
  lastRemoved.value = null;
};

const widgetName = id =>
  draft.value.find(item => item.id === id)?.title || widgetLabels.value[id];

const removeWidget = id => {
  const removed = { items: draft.value, name: widgetName(id) };
  changeLayout(removeItem(draft.value, id));
  lastRemoved.value = removed;
};

const undoRemove = () => changeLayout(lastRemoved.value.items);

const renameWidget = (id, title) =>
  changeLayout(renameItem(draft.value, id, title));

const addWidget = async id => {
  changeLayout(addItem(draft.value, id));
  catalogDialog.value?.close();
  await nextTick();
  document.querySelector(`[data-widget-id="${id}"]`)?.focus();
};

const confirmReset = () => {
  draft.value = visibleLayout(
    resolveLayout({ account: teamLayout.value }),
    availableIds.value
  );
  followDefault.value = true;
  lastRemoved.value = null;
  resetDialog.value?.close();
};

const finishEditing = async () => {
  isSaving.value = true;
  const layout = layoutToSave(
    draft.value,
    baseLayout.value,
    availableIds.value
  );
  const layouts = { ...savedLayouts.value };
  if (followDefault.value) delete layouts[accountKey.value];
  else layouts[accountKey.value] = layout;
  updateUISettings({ raevo_home_layout: layouts });

  if (applyToTeam.value && canSetTeam.value) {
    try {
      const response = await RaevoHomeAPI.saveTeamLayout(layout);
      data.value = {
        ...data.value,
        layout: { ...data.value.layout, team: response.data.team_layout },
      };
    } catch {
      useAlert(t('HOME.LAYOUT.SAVE_ERROR'));
    }
  }

  isSaving.value = false;
  stopEditing();
  useAlert(t('HOME.LAYOUT.SAVED'));
};

// Quantas linhas cabem no bloco. A altura vem medida da moldura; o cabeçalho
// da secção mede ≈49px e cada linha tem a altura do seu degrau. Empilhado, no
// telemóvel, a altura é a do conteúdo e cabe tudo o que o servidor mandou.
const SECTION_HEADER_PX = 49;
const ROW_PX = {
  conversation: { sm: 52, md: 62, lg: 68 },
  payment: { sm: 66, md: 80, lg: 88 },
  appointment: { sm: 84, md: 96, lg: 104 },
};
const rowsThatFit = (slot, row) =>
  slot.stacked
    ? Infinity
    : Math.max(
        1,
        Math.floor((slot.height - SECTION_HEADER_PX) / ROW_PX[row][slot.tier])
      );
// Quando há mais conversas do que linhas, a última linha é o «Ver todas»: sem
// esta reserva o botão ficava cortado no fundo do bloco.
const conversationRows = slot => {
  const fit = rowsThatFit(slot, 'conversation');
  const total = Number(data.value.open_conversations_count || 0);
  const shown =
    total > fit
      ? openConversations.value.slice(0, Math.max(1, fit - 1))
      : openConversations.value.slice(0, fit);
  return { shown, hidden: Math.max(total - shown.length, 0) };
};
const APPOINTMENT_MIN_COLUMN_PX = 160;
const appointmentsThatFit = slot =>
  slot.stacked
    ? Infinity
    : Math.max(1, Math.floor(slot.width / APPOINTMENT_MIN_COLUMN_PX)) *
      rowsThatFit(slot, 'appointment');

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
    loadInsights({ reset: true });
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

const formatPercent = value =>
  value === null || value === undefined
    ? null
    : `${new Intl.NumberFormat(intlLocale.value, { maximumFractionDigits: 1 }).format(value)}%`;

const MINUTE = 60;
const HOUR = 3600;
const formatDuration = seconds => {
  if (seconds === null || seconds === undefined) return null;
  if (seconds < MINUTE) return t('HOME.INSIGHTS.SECONDS', { count: seconds });
  if (seconds < HOUR) {
    return t('HOME.INSIGHTS.MINUTES', { count: Math.round(seconds / MINUTE) });
  }
  return t('HOME.INSIGHTS.HOURS', {
    hours: Math.floor(seconds / HOUR),
    minutes: Math.round((seconds % HOUR) / MINUTE),
  });
};

// Cada insight vira um cartão de número como os outros. Enquanto não chega, o
// valor é `null` e o cartão mostra o travessão — nunca um zero que mentiria.
const INSIGHT_CARDS = {
  'kpi-pipeline-value': v => ({
    value: v && formatMoney(v.amount_cents, v.currency),
    footer: t('HOME.INSIGHTS.PIPELINE_FOOTER'),
  }),
  'kpi-close-rate': v => ({
    value: v && formatPercent(v.rate),
    footer: v ? t('HOME.INSIGHTS.CLOSE_RATE_FOOTER', { count: v.closed }) : '',
  }),
  'kpi-won-month': v => ({
    value: v && String(v.count),
    footer: v ? formatMoney(v.amount_cents, v.currency) : '',
  }),
  'kpi-first-response': v => ({
    value: v && formatDuration(v.today_seconds),
    footer:
      v && v.week_seconds !== null
        ? t('HOME.INSIGHTS.FIRST_RESPONSE_FOOTER', {
            week: formatDuration(v.week_seconds),
          })
        : '',
  }),
  'kpi-attendance': v => ({
    value: v && formatPercent(v.rate),
    footer: v
      ? t('HOME.INSIGHTS.ATTENDANCE_FOOTER', {
          noShow: v.no_show,
          canceled: v.canceled,
        })
      : '',
  }),
  'kpi-ai-opportunities': v => ({
    value: v && String(v.count),
    footer: v ? t('HOME.INSIGHTS.AI_FOOTER', { days: v.window_days }) : '',
  }),
  'kpi-waiting-24h': v => ({
    value: v && String(v.count),
    footer: t('HOME.INSIGHTS.WAITING_FOOTER'),
  }),
};

const indicatorByWidget = computed(() => ({
  ...Object.fromEntries(homeIndicators.value.map(card => [card.widget, card])),
  ...Object.fromEntries(
    INSIGHT_IDS.map(id => [
      id,
      {
        widget: id,
        chave: id.replace('kpi-', ''),
        label: widgetLabels.value[id],
        ...INSIGHT_CARDS[id](insights.value[id]),
      },
    ])
  ),
}));

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
  <div class="h-full w-full overflow-y-auto">
    <main class="mx-auto flex w-full max-w-[96rem] flex-col gap-4 p-4 lg:p-6">
      <RaevoPageHeader
        :eyebrow="t('HOME.EYEBROW')"
        :title="t('HOME.TITLE')"
        :badge="String(totalAttention)"
        :subtitle="t('HOME.SUBTITLE')"
      >
        <template #actions>
          <button
            v-if="!editing"
            type="button"
            class="inline-flex size-9 items-center justify-center rounded-lg text-n-slate-11 hover:bg-n-alpha-2 focus:outline-none focus:ring-2 focus:ring-n-brand/40"
            :aria-label="t('HOME.REFRESH')"
            :title="t('HOME.REFRESH')"
            @click="loadHome"
          >
            <i class="i-lucide-refresh-cw size-4" aria-hidden="true" />
          </button>
          <!--
            Editar só em ecrã de computador: abaixo de 1024px a grelha empilha
            numa coluna e não há o que arrumar ao lado.
          -->
          <button
            v-if="!editing && !isLoading && !hasError"
            type="button"
            data-testid="home-edit"
            class="hidden h-9 items-center gap-2 rounded-lg border border-solid border-n-weak bg-n-solid-1 px-3 text-sm font-medium text-n-slate-12 hover:bg-n-alpha-2 focus:outline-none focus:ring-2 focus:ring-n-brand/40 lg:inline-flex"
            :title="t('HOME.LAYOUT.EDIT_HINT')"
            @click="startEditing"
          >
            <i class="i-lucide-pencil size-4" aria-hidden="true" />
            {{ t('HOME.LAYOUT.EDIT') }}
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
            <option
              v-for="value in PERIODS"
              :key="value || 'all'"
              :value="value"
            >
              {{ t(`HOME.PERIOD.${value || 'ALL'}`) }}
            </option>
          </select>
        </div>

        <!--
        A barra de edição fica por baixo dos filtros e nunca por cima de um
        bloco: o foco de quem arruma por teclado não pode ficar tapado (WCAG
        2.2, 2.4.11). Nada se grava antes de «Concluir».
      -->
        <div
          v-if="editing"
          data-testid="home-edit-bar"
          class="flex flex-wrap items-center gap-2 rounded-xl border border-solid border-n-weak bg-n-solid-2 px-3 py-2 text-sm text-n-slate-12"
        >
          <i
            class="i-lucide-layout-dashboard size-4 text-n-slate-11"
            aria-hidden="true"
          />
          <span role="status" class="min-w-0 flex-1">
            {{
              lastRemoved
                ? t('HOME.LAYOUT.REMOVED', { name: lastRemoved.name })
                : t('HOME.LAYOUT.EDITING')
            }}
          </span>
          <button
            v-if="lastRemoved"
            type="button"
            data-testid="home-undo-remove"
            class="h-8 rounded-lg px-2 font-medium text-n-slate-12 underline hover:bg-n-alpha-2 focus:outline-none focus:ring-2 focus:ring-n-brand/40"
            @click="undoRemove"
          >
            {{ t('HOME.LAYOUT.UNDO') }}
          </button>
          <label
            v-if="canSetTeam"
            class="inline-flex items-center gap-2 text-n-slate-12"
            :title="t('HOME.LAYOUT.APPLY_TEAM_HINT')"
          >
            <input
              v-model="applyToTeam"
              data-testid="home-apply-team"
              type="checkbox"
              class="size-4"
            />
            {{ t('HOME.LAYOUT.APPLY_TEAM') }}
          </label>
          <button
            type="button"
            data-testid="home-reset-layout"
            class="h-8 rounded-lg px-2 font-medium text-n-slate-12 hover:bg-n-alpha-2 focus:outline-none focus:ring-2 focus:ring-n-brand/40"
            @click="resetDialog.open()"
          >
            {{ t('HOME.LAYOUT.RESET') }}
          </button>
          <button
            type="button"
            data-testid="home-cancel-edit"
            class="h-8 rounded-lg border border-solid border-n-weak bg-n-solid-1 px-3 font-medium text-n-slate-12 hover:bg-n-alpha-2 focus:outline-none focus:ring-2 focus:ring-n-brand/40"
            @click="stopEditing"
          >
            {{ t('HOME.LAYOUT.CANCEL') }}
          </button>
          <button
            type="button"
            data-testid="home-finish-edit"
            class="h-8 rounded-lg bg-n-brand px-3 font-medium text-n-solid-1 focus:outline-none focus:ring-2 focus:ring-n-brand/40 disabled:opacity-50"
            :disabled="isSaving"
            @click="finishEditing"
          >
            {{ t('HOME.LAYOUT.DONE') }}
          </button>
        </div>

        <!--
        Os blocos vivem numa grelha que cada pessoa arruma (18/10). O conteúdo
        de cada um acompanha o tamanho em três degraus — `tier` sm/md/lg — e as
        listas mostram as linhas que cabem. Agenda e Financeiro só existem se o
        módulo estiver em uso: `null` do servidor quer dizer «não mostrar».
      -->
        <RaevoHomeGrid
          :items="shownLayout"
          :editing="editing"
          :labels="widgetLabels"
          @update:items="changeLayout"
          @remove="removeWidget"
          @rename="renameWidget"
          @add="catalogDialog.open()"
        >
          <template #widget="{ item, ...slot }">
            <RaevoKpiCard
              v-if="indicatorByWidget[item.id]"
              :data-testid="`home-kpi-${indicatorByWidget[item.id].chave}`"
              class="h-full content-start overflow-hidden"
              :size="slot.tier"
              :label="item.title || indicatorByWidget[item.id].label"
              :value="indicatorByWidget[item.id].value"
              :footer="
                slot.tier === 'sm' ? '' : indicatorByWidget[item.id].footer
              "
            />

            <!--
            A agenda é a única lista com forma de tempo: colunas por hora, tantas
            quantas a largura do bloco deixar.
          -->
            <section
              v-else-if="item.id === 'today-appointments' && todayAppointments"
              data-testid="home-today-appointments"
              class="flex h-full flex-col overflow-hidden rounded-xl border border-n-weak bg-n-solid-1"
            >
              <div
                class="flex items-center justify-between gap-2 border-b border-n-weak px-4 py-3"
              >
                <div class="flex min-w-0 items-center gap-2">
                  <i
                    class="i-lucide-calendar size-4 text-n-slate-11"
                    aria-hidden="true"
                  />
                  <h2
                    class="font-semibold text-n-slate-12"
                    :class="slot.tier === 'lg' ? 'text-base' : 'text-sm'"
                  >
                    {{ item.title || t('HOME.TODAY_APPOINTMENTS') }}
                  </h2>
                  <RaevoStamp
                    :label="String(todayAppointments.count)"
                    size="sm"
                  />
                </div>
              </div>
              <ul
                v-if="todayAppointments.items.length"
                class="grid min-h-0 flex-1 grid-cols-[repeat(auto-fill,minmax(10rem,1fr))] content-start divide-y divide-n-weak overflow-hidden sm:divide-y-0"
              >
                <li
                  v-for="appointment in todayAppointments.items.slice(
                    0,
                    appointmentsThatFit(slot)
                  )"
                  :key="appointment.id"
                  class="flex min-w-0 flex-col gap-0.5 px-4 py-3 sm:border-e sm:border-n-weak"
                >
                  <span
                    class="font-semibold tabular-nums text-n-slate-12"
                    :class="{
                      'text-sm': slot.tier === 'sm',
                      'text-base': slot.tier === 'md',
                      'text-xl': slot.tier === 'lg',
                    }"
                    :title="formatDateTime(appointment.starts_at)"
                  >
                    {{ formatTime(appointment.starts_at) }}
                  </span>
                  <span
                    class="break-words text-n-slate-12"
                    :class="slot.tier === 'sm' ? 'text-xs' : 'text-sm'"
                  >
                    {{ appointment.procedure_name }}
                  </span>
                  <span class="break-words text-xs text-n-slate-11">
                    {{ appointment.contact_name }}
                  </span>
                  <span
                    class="text-micro uppercase tracking-wide text-n-slate-10"
                  >
                    {{
                      t(
                        `HOME.APPOINTMENT_STATUS.${appointment.status.toUpperCase()}`
                      )
                    }}
                  </span>
                </li>
              </ul>
              <p v-else class="px-4 py-6 text-center text-sm text-n-slate-10">
                {{ t('HOME.EMPTY_APPOINTMENTS') }}
              </p>
            </section>

            <section
              v-else-if="item.id === 'open-conversations'"
              data-testid="home-open-conversations"
              class="flex h-full flex-col overflow-hidden rounded-xl border border-n-weak bg-n-solid-1"
            >
              <div
                class="flex items-center justify-between border-b border-n-weak px-4 py-3"
              >
                <div class="flex min-w-0 items-center gap-2">
                  <i
                    class="i-lucide-message-circle size-4 text-n-brand"
                    aria-hidden="true"
                  />
                  <h2
                    class="font-semibold text-n-slate-12"
                    :class="slot.tier === 'lg' ? 'text-base' : 'text-sm'"
                  >
                    {{ item.title || t('HOME.OPEN_CONVERSATIONS') }}
                  </h2>
                </div>
                <div class="flex shrink-0 items-center gap-2">
                  <select
                    v-if="slot.tier !== 'sm'"
                    v-model="conversationSort"
                    data-testid="home-sort-conversations"
                    class="reset-base mb-0 h-8 rounded-lg border border-solid border-n-weak bg-n-solid-1 px-2 text-xs text-n-slate-11"
                    :aria-label="t('HOME.SORT_CONVERSATIONS')"
                    @change="applyChoice"
                  >
                    <option value="waiting">
                      {{ t('HOME.SORT_WAITING') }}
                    </option>
                    <option value="recent">{{ t('HOME.SORT_RECENT') }}</option>
                  </select>
                  <RaevoStamp
                    :label="String(data.open_conversations_count || 0)"
                    size="sm"
                  />
                </div>
              </div>
              <div
                v-if="openConversations.length"
                class="min-h-0 flex-1 divide-y divide-n-weak overflow-hidden"
              >
                <button
                  v-for="conversation in conversationRows(slot).shown"
                  :key="conversation.id"
                  type="button"
                  class="flex w-full items-center gap-3 px-4 py-3 text-left hover:bg-n-alpha-2 focus:outline-none focus:ring-2 focus:ring-inset focus:ring-n-brand/40"
                  @click="openConversation(conversation)"
                >
                  <span
                    v-if="slot.tier !== 'sm'"
                    class="grid size-8 shrink-0 place-items-center rounded-full bg-n-blue-3 text-n-blue-11"
                  >
                    <i
                      class="i-lucide-message-circle size-4"
                      aria-hidden="true"
                    />
                  </span>
                  <span class="min-w-0 flex-1">
                    <span
                      class="block break-words font-medium text-n-slate-12"
                      :class="{
                        'text-xs': slot.tier === 'sm',
                        'text-sm': slot.tier === 'md',
                        'text-base': slot.tier === 'lg',
                      }"
                    >
                      {{
                        conversation.contact_name || t('HOME.UNKNOWN_CONTACT')
                      }}
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
                  v-if="conversationRows(slot).hidden"
                  type="button"
                  data-testid="home-see-all-conversations"
                  class="flex w-full items-center justify-center px-4 py-3 text-sm font-medium text-n-brand hover:bg-n-alpha-2 focus:outline-none focus:ring-2 focus:ring-inset focus:ring-n-brand/40"
                  @click="goToAllConversations"
                >
                  {{
                    t('HOME.SEE_ALL', { count: conversationRows(slot).hidden })
                  }}
                </button>
              </div>
              <p v-else class="px-4 py-10 text-center text-sm text-n-slate-10">
                {{ t('HOME.EMPTY_CONVERSATIONS') }}
              </p>
            </section>

            <section
              v-else-if="
                item.id === 'stale-opportunities' && staleOpportunities
              "
              data-testid="home-stale-opportunities"
              class="flex h-full flex-col overflow-hidden rounded-xl border border-n-weak bg-n-solid-1"
            >
              <div
                class="flex items-center gap-2 border-b border-n-weak px-4 py-3"
              >
                <i
                  class="i-lucide-circle-pause size-4 text-n-amber-11"
                  aria-hidden="true"
                />
                <h2
                  class="font-semibold text-n-slate-12"
                  :class="slot.tier === 'lg' ? 'text-base' : 'text-sm'"
                >
                  {{ item.title || t('HOME.STALE_OPPORTUNITIES') }}
                </h2>
                <RaevoStamp
                  variant="warning"
                  :label="railLabel(staleOpportunities)"
                  size="sm"
                />
              </div>
              <div
                v-if="staleOpportunities.items.length"
                class="min-h-0 flex-1 divide-y divide-n-weak overflow-hidden"
              >
                <button
                  v-for="card in staleOpportunities.items.slice(
                    0,
                    rowsThatFit(slot, 'conversation')
                  )"
                  :key="card.kanban_card_id"
                  type="button"
                  class="flex w-full flex-col gap-0.5 px-4 py-3 text-left hover:bg-n-alpha-2 focus:outline-none focus:ring-2 focus:ring-inset focus:ring-n-brand/40"
                  @click="openOpportunity(card)"
                >
                  <span
                    class="break-words font-medium text-n-slate-12"
                    :class="{
                      'text-xs': slot.tier === 'sm',
                      'text-sm': slot.tier === 'md',
                      'text-base': slot.tier === 'lg',
                    }"
                  >
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
              <p v-else class="px-4 py-10 text-center text-sm text-n-slate-10">
                {{ t('HOME.EMPTY_STALE') }}
              </p>
            </section>

            <section
              v-else-if="item.id === 'overdue-actions'"
              data-testid="home-overdue-actions"
              class="flex h-full flex-col overflow-hidden rounded-xl border border-n-weak bg-n-solid-1"
            >
              <div
                class="flex items-center justify-between border-b border-n-weak px-4 py-3"
              >
                <div class="flex min-w-0 items-center gap-2">
                  <i
                    class="i-lucide-clock-alert size-4 text-n-ruby-11"
                    aria-hidden="true"
                  />
                  <h2
                    class="font-semibold text-n-slate-12"
                    :class="slot.tier === 'lg' ? 'text-base' : 'text-sm'"
                  >
                    {{ item.title || t('HOME.OVERDUE_ACTIONS') }}
                  </h2>
                </div>
                <div class="flex shrink-0 items-center gap-2">
                  <select
                    v-if="slot.tier !== 'sm'"
                    v-model="actionSort"
                    data-testid="home-sort-actions"
                    class="reset-base mb-0 h-8 rounded-lg border border-solid border-n-weak bg-n-solid-1 px-2 text-xs text-n-slate-11"
                    :aria-label="t('HOME.SORT_ACTIONS')"
                    @change="applyChoice"
                  >
                    <option value="overdue">
                      {{ t('HOME.SORT_OVERDUE') }}
                    </option>
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
              <div
                v-if="overdueActions.length"
                class="min-h-0 flex-1 divide-y divide-n-weak overflow-hidden"
              >
                <button
                  v-for="action in overdueActions.slice(
                    0,
                    rowsThatFit(slot, 'conversation')
                  )"
                  :key="action.kanban_card_id"
                  type="button"
                  class="flex w-full items-center gap-3 px-4 py-3 text-left hover:bg-n-alpha-2 focus:outline-none focus:ring-2 focus:ring-inset focus:ring-n-brand/40"
                  @click="openOpportunity(action)"
                >
                  <span
                    v-if="slot.tier !== 'sm'"
                    class="grid size-8 shrink-0 place-items-center rounded-full bg-n-ruby-3 text-n-ruby-11"
                  >
                    <i class="i-lucide-clock-alert size-4" aria-hidden="true" />
                  </span>
                  <span class="min-w-0 flex-1">
                    <span
                      class="block break-words font-medium text-n-slate-12"
                      :class="{
                        'text-xs': slot.tier === 'sm',
                        'text-sm': slot.tier === 'md',
                        'text-base': slot.tier === 'lg',
                      }"
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
            O Financeiro é opt-in por conta e exige permissão para ver cobranças.
            Sem as duas coisas o servidor devolve nil e o bloco não existe.
          -->
            <section
              v-else-if="item.id === 'overdue-payments' && overduePayments"
              data-testid="home-overdue-payments"
              class="flex h-full flex-col overflow-hidden rounded-xl border border-n-weak bg-n-solid-1"
            >
              <div
                class="flex items-center gap-2 border-b border-n-weak px-4 py-3"
              >
                <i
                  class="i-lucide-receipt-text size-4 text-n-ruby-11"
                  aria-hidden="true"
                />
                <h2
                  class="font-semibold text-n-slate-12"
                  :class="slot.tier === 'lg' ? 'text-base' : 'text-sm'"
                >
                  {{ item.title || t('HOME.OVERDUE_PAYMENTS') }}
                </h2>
                <RaevoStamp
                  variant="danger"
                  :label="String(overduePayments.count)"
                  size="sm"
                />
              </div>
              <div
                v-if="overduePayments.items.length"
                class="min-h-0 flex-1 divide-y divide-n-weak overflow-hidden"
              >
                <button
                  v-for="payment in overduePayments.items.slice(
                    0,
                    rowsThatFit(slot, 'payment')
                  )"
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
                  <span
                    class="break-words font-medium text-n-slate-12"
                    :class="{
                      'text-xs': slot.tier === 'sm',
                      'text-sm': slot.tier === 'md',
                      'text-base': slot.tier === 'lg',
                    }"
                  >
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
              <p v-else class="px-4 py-10 text-center text-sm text-n-slate-10">
                {{ t('HOME.EMPTY_PAYMENTS') }}
              </p>
            </section>
          </template>
        </RaevoHomeGrid>

        <Dialog
          ref="catalogDialog"
          :title="t('HOME.LAYOUT.CATALOG_TITLE')"
          :show-confirm-button="false"
          :cancel-button-label="t('HOME.LAYOUT.CLOSE')"
        >
          <ul v-if="catalog.length" class="grid gap-2">
            <li
              v-for="entry in catalog"
              :key="entry.id"
              class="flex items-center justify-between gap-3 rounded-lg border border-solid border-n-weak px-3 py-2"
            >
              <span class="grid min-w-0">
                <span class="break-words text-sm font-medium text-n-slate-12">
                  {{ entry.label }}
                </span>
                <span class="text-xs text-n-slate-11">{{ entry.kind }}</span>
              </span>
              <button
                type="button"
                :data-testid="`home-catalog-add-${entry.id}`"
                class="h-8 shrink-0 rounded-lg border border-solid border-n-weak bg-n-solid-1 px-3 text-sm font-medium text-n-slate-12 hover:bg-n-alpha-2 focus:outline-none focus:ring-2 focus:ring-n-brand/40"
                @click="addWidget(entry.id)"
              >
                {{ t('HOME.LAYOUT.CATALOG_ADD') }}
              </button>
            </li>
          </ul>
          <p v-else class="text-sm text-n-slate-11">
            {{ t('HOME.LAYOUT.CATALOG_EMPTY') }}
          </p>
        </Dialog>

        <Dialog
          ref="resetDialog"
          type="alert"
          :title="t('HOME.LAYOUT.RESET_TITLE')"
          :description="t('HOME.LAYOUT.RESET_BODY')"
          :confirm-button-label="t('HOME.LAYOUT.RESET')"
          @confirm="confirmReset"
        />
      </div>
    </main>
  </div>
</template>
