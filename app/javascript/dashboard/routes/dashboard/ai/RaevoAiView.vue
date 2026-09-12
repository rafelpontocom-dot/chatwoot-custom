<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAdmin } from 'dashboard/composables/useAdmin';
import RaevoPageHeader from 'dashboard/components-next/raevo/RaevoPageHeader.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import RaevoAiKnowledgePanel from './RaevoAiKnowledgePanel.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import RaevoAiAPI from 'dashboard/api/raevoAi';
import RaevoAiServiceHoursSettings from './RaevoAiServiceHoursSettings.vue';

const { t } = useI18n();

// Três abas, e a separação não é arbitrária: «Painel» é o que a clínica vem
// ver, «A Elis» é o que ela configura, «Conhecimento» é o que a Elis sabe
// responder. Antes disto vivia tudo numa coluna só e o que importava ficava
// abaixo da dobra.
const abaAtiva = ref('panel');
const abas = computed(() => [
  { key: 'panel', label: t('RAEVO_AI.TABS.PANEL') },
  { key: 'assistant', label: t('RAEVO_AI.TABS.ASSISTANT') },
  { key: 'knowledge', label: t('RAEVO_AI.TABS.KNOWLEDGE') },
]);
const indiceDaAba = computed(() =>
  abas.value.findIndex(aba => aba.key === abaAtiva.value)
);
const mudarAba = aba => {
  abaAtiva.value = aba.key;
};

// A janela que a clínica escolheu ver. Trinta dias por omissão porque é o que
// responde «como foi o mês», que é a pergunta que ela traz.
const windowDays = ref(30);
const windowOptions = [7, 30, 90];

// Pausa: o estado vem do serviço, e é ele que o botão altera. Sem isto o botão
// existia no ecrã e não parava nada — foi assim durante toda a construção.
const pauseState = ref(null);
const isSavingPause = ref(false);
const pauseError = ref(null);

// O que a Elis fez e o que ficou por resolver.
const activity = ref({ recent: [], attention: { failed: 0, pending: 0 } });

const overview = ref(null);
const isLoading = ref(true);
const hasError = ref(false);
const isPreparing = ref(false);
const isDisabled = ref(false);
const { isAdmin } = useAdmin();
const formatTokens = value =>
  Number.isFinite(Number(value))
    ? new Intl.NumberFormat('en-US').format(Number(value))
    : '—';
const formatUsd = value => `US$ ${Number(value || 0).toFixed(2)}`;

const usage = computed(() => overview.value?.usage_30d || {});

const usageCost = computed(() => {
  const reported = Number(usage.value.provider_reported_cost_usd || 0);
  const estimated = Number(usage.value.catalog_estimated_cost_usd || 0);
  const unavailable = Number(usage.value.cost_unavailable_calls || 0);
  const parts = [];

  if (reported > 0) parts.push(formatUsd(reported));
  if (estimated > 0) parts.push(`${formatUsd(estimated)} est.`);
  if (unavailable > 0) parts.push(`${unavailable} indisponível`);

  return parts.length ? parts.join(' · ') : '—';
});

const overviewMetrics = computed(() => [
  {
    key: 'CONVERSATIONS',
    label: t('RAEVO_AI.OVERVIEW.METRICS.CONVERSATIONS', {
      days: windowDays.value,
    }),
    value: overview.value?.usage_30d?.conversations,
  },
  {
    key: 'HANDOFFS',
    label: t('RAEVO_AI.OVERVIEW.METRICS.HANDOFFS', { days: windowDays.value }),
    value: overview.value?.usage_30d?.handoffs,
  },
  {
    key: 'APPOINTMENTS',
    label: t('RAEVO_AI.OVERVIEW.METRICS.APPOINTMENTS', {
      days: windowDays.value,
    }),
    value: overview.value?.usage_30d?.appointments,
  },
  {
    key: 'PAYMENTS',
    label: t('RAEVO_AI.OVERVIEW.METRICS.PAYMENTS', { days: windowDays.value }),
    value: overview.value?.usage_30d?.payments,
  },
  {
    key: 'KNOWLEDGE',
    label: t('RAEVO_AI.OVERVIEW.METRICS.KNOWLEDGE'),
    value: overview.value?.knowledge_count,
  },
  {
    key: 'PROMPT_VERSION',
    label: t('RAEVO_AI.OVERVIEW.METRICS.PROMPT_VERSION'),
    value: overview.value?.active_prompt_version,
  },
  {
    key: 'OPEN_REVIEWS',
    label: t('RAEVO_AI.OVERVIEW.METRICS.OPEN_REVIEWS'),
    value: overview.value?.open_reviews,
  },
  {
    key: 'TOKENS',
    label: t('RAEVO_AI.OVERVIEW.METRICS.TOKENS', { days: windowDays.value }),
    value: formatTokens(
      Number(usage.value.prompt_tokens || 0) +
        Number(usage.value.completion_tokens || 0)
    ),
  },
  {
    key: 'COST',
    label: t('RAEVO_AI.OVERVIEW.METRICS.COST', { days: windowDays.value }),
    value: usageCost.value,
  },
]);
const capabilityLabels = {
  atendimento: t('RAEVO_AI.CAPABILITIES.ITEMS.ATENDIMENTO'),
  crm: t('RAEVO_AI.CAPABILITIES.ITEMS.CRM'),
  agenda: t('RAEVO_AI.CAPABILITIES.ITEMS.AGENDA'),
  observabilidade: t('RAEVO_AI.CAPABILITIES.ITEMS.OBSERVABILITY'),
};
const capabilityProviderLabels = {
  chatwoot: t('RAEVO_AI.CAPABILITIES.PROVIDERS.CHATWOOT'),
  kommo: t('RAEVO_AI.CAPABILITIES.PROVIDERS.KOMMO'),
  calcom: t('RAEVO_AI.CAPABILITIES.PROVIDERS.CALCOM'),
  google_calendar: t('RAEVO_AI.CAPABILITIES.PROVIDERS.GOOGLE_CALENDAR'),
  feegow: t('RAEVO_AI.CAPABILITIES.PROVIDERS.FEEGOW'),
  chatwoot_native: t('RAEVO_AI.CAPABILITIES.PROVIDERS.CHATWOOT_NATIVE'),
};
const activeCapabilities = computed(() => {
  const capabilities = overview.value?.capabilities?.capabilities;
  if (!Array.isArray(capabilities)) return [];

  return capabilities
    .map(capability => ({
      id: capability?.id,
      label: capabilityLabels[capability?.id],
      provider: capabilityProviderLabels[capability?.provider] || null,
    }))
    .filter(capability => capability.label);
});

// `command_type` chega como `crm.move_stage`; o ecrã da clínica não mostra
// identificadores de sistema. O mapa é explícito, e não uma chave montada por
// interpolação, para uma tradução em falta ser encontrada pelas ferramentas em
// vez de aparecer como texto cru ao cliente.
const commandLabels = computed(() => ({
  'calendar.book_appointment': t(
    'RAEVO_AI.ACTIVITY.COMMANDS.CALENDAR_BOOK_APPOINTMENT'
  ),
  'crm.add_label': t('RAEVO_AI.ACTIVITY.COMMANDS.CRM_ADD_LABEL'),
  'crm.ensure_opportunity': t(
    'RAEVO_AI.ACTIVITY.COMMANDS.CRM_ENSURE_OPPORTUNITY'
  ),
  'crm.move_stage': t('RAEVO_AI.ACTIVITY.COMMANDS.CRM_MOVE_STAGE'),
  'crm.update_contact_name': t(
    'RAEVO_AI.ACTIVITY.COMMANDS.CRM_UPDATE_CONTACT_NAME'
  ),
  'crm.update_fields': t('RAEVO_AI.ACTIVITY.COMMANDS.CRM_UPDATE_FIELDS'),
  'finance.create_charge': t(
    'RAEVO_AI.ACTIVITY.COMMANDS.FINANCE_CREATE_CHARGE'
  ),
  'handoff.apply': t('RAEVO_AI.ACTIVITY.COMMANDS.HANDOFF_APPLY'),
}));

const stateLabels = computed(() => ({
  applied: t('RAEVO_AI.ACTIVITY.STATE_APPLIED'),
  claimed: t('RAEVO_AI.ACTIVITY.STATE_CLAIMED'),
  failed_retryable: t('RAEVO_AI.ACTIVITY.STATE_FAILED_RETRYABLE'),
  failed_terminal: t('RAEVO_AI.ACTIVITY.STATE_FAILED_TERMINAL'),
}));

const commandLabel = tipo =>
  commandLabels.value[tipo] ?? t('RAEVO_AI.ACTIVITY.COMMANDS.UNKNOWN');

const stateLabel = estado =>
  stateLabels.value[estado] ?? t('RAEVO_AI.ACTIVITY.STATE_UNKNOWN');

const formatMoment = iso => {
  if (!iso) return '—';
  const quando = new Date(iso);
  return Number.isNaN(quando.getTime())
    ? '—'
    : new Intl.DateTimeFormat(undefined, {
        dateStyle: 'short',
        timeStyle: 'short',
      }).format(quando);
};

const displayValue = value => value ?? '—';

const loadOverview = async () => {
  isLoading.value = true;
  hasError.value = false;
  isPreparing.value = false;
  isDisabled.value = false;

  try {
    const { data } = await RaevoAiAPI.getOverview(windowDays.value);
    const connectionState = data?.connection_state;
    overview.value = connectionState ? data.overview : data;
    isPreparing.value = connectionState === 'not_configured';
    isDisabled.value = connectionState === 'disabled';
    hasError.value = connectionState === 'unavailable';
  } catch (error) {
    overview.value = null;
    isPreparing.value = error?.response?.status === 404;
    hasError.value = !isPreparing.value;
  } finally {
    isLoading.value = false;
  }
};

const loadPauseState = async () => {
  try {
    const { data } = await RaevoAiAPI.getPauseState();
    pauseState.value = data.state;
  } catch {
    // O painel não fica refém do estado de pausa: sem ele o botão esconde-se,
    // em vez de o ecrã inteiro falhar por causa de um controlo.
    pauseState.value = null;
  }
};

const loadActivity = async () => {
  try {
    const { data } = await RaevoAiAPI.getActivity();
    activity.value = data;
  } catch {
    activity.value = { recent: [], attention: { failed: 0, pending: 0 } };
  }
};

const togglePause = async () => {
  const queroPausar = !pauseState.value?.paused;
  // Pausar faz a clínica deixar de responder ao paciente: pede confirmação.
  // Retomar não pede — voltar a atender não é a decisão arriscada.
  // eslint-disable-next-line no-alert
  if (queroPausar && !window.confirm(t('RAEVO_AI.PAUSE.CONFIRM'))) return;

  isSavingPause.value = true;
  pauseError.value = null;
  try {
    const { data } = await RaevoAiAPI.savePauseState({
      paused: queroPausar,
      expected_revision: pauseState.value?.revision ?? null,
    });
    pauseState.value = data.state;
  } catch (e) {
    pauseError.value =
      e?.response?.status === 409
        ? t('RAEVO_AI.PAUSE.CONFLICT')
        : t('RAEVO_AI.PAUSE.UNAVAILABLE');
  } finally {
    isSavingPause.value = false;
  }
};

const changeWindow = async dias => {
  windowDays.value = dias;
  await loadOverview();
};

onMounted(loadOverview);
onMounted(loadPauseState);
onMounted(loadActivity);

const servicePackages = computed(() => [
  {
    key: 'QUALIFY_HANDOFF',
    icon: 'i-lucide-messages-square',
    title: t('RAEVO_AI.PACKAGES.QUALIFY_HANDOFF.TITLE'),
    description: t('RAEVO_AI.PACKAGES.QUALIFY_HANDOFF.DESCRIPTION'),
  },
  {
    key: 'SCHEDULE',
    icon: 'i-lucide-calendar-check-2',
    title: t('RAEVO_AI.PACKAGES.SCHEDULE.TITLE'),
    description: t('RAEVO_AI.PACKAGES.SCHEDULE.DESCRIPTION'),
  },
  {
    key: 'COMPLETE',
    icon: 'i-lucide-badge-dollar-sign',
    title: t('RAEVO_AI.PACKAGES.COMPLETE.TITLE'),
    description: t('RAEVO_AI.PACKAGES.COMPLETE.DESCRIPTION'),
  },
]);

// Só o pacote contratado aparece: mostrar os três transformava o painel da
// clínica num folheto do que ela não comprou.
//
// O runtime nomeia os pacotes à sua maneira; esta tabela é a tradução para os
// três do ecrã. Pacote desconhecido não mostra nada — inventar qual seria pior
// do que dizer que ainda não se sabe.
const PACKAGE_BY_RUNTIME = {
  atendimento_basico: 'QUALIFY_HANDOFF',
  crm: 'QUALIFY_HANDOFF',
  agenda: 'SCHEDULE',
  completo: 'COMPLETE',
};

const contractedPackage = computed(() => {
  const key = PACKAGE_BY_RUNTIME[overview.value?.package];
  return servicePackages.value.find(item => item.key === key) ?? null;
});
</script>

<template>
  <main
    data-testid="ai-workspace"
    class="flex min-h-0 w-full min-w-0 flex-1 flex-col overflow-y-auto bg-n-background px-4 py-5 pb-10 sm:px-6 lg:px-8"
  >
    <div class="mx-auto flex w-full max-w-[96rem] flex-col gap-4">
      <RaevoPageHeader
        :eyebrow="t('RAEVO_AI.EYEBROW')"
        :title="t('RAEVO_AI.TITLE')"
        :subtitle="t('RAEVO_AI.SUBTITLE')"
      >
        <template #actions>
          <div v-if="pauseState" class="flex items-center gap-2">
            <span
              data-testid="ai-pause-state"
              class="flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-medium"
              :class="
                pauseState.paused
                  ? 'bg-n-amber-3 text-n-amber-11'
                  : 'bg-n-teal-3 text-n-teal-11'
              "
            >
              <i
                :class="
                  pauseState.paused
                    ? 'i-lucide-circle-pause'
                    : 'i-lucide-circle-check'
                "
                class="size-3.5"
                aria-hidden="true"
              />
              {{
                pauseState.paused
                  ? t('RAEVO_AI.PAUSE.STATE_PAUSED')
                  : t('RAEVO_AI.PAUSE.STATE_ACTIVE')
              }}
            </span>
            <NextButton
              v-if="isAdmin"
              data-testid="ai-pause-toggle"
              size="sm"
              :variant="pauseState.paused ? 'solid' : 'faded'"
              :is-loading="isSavingPause"
              :label="
                pauseState.paused
                  ? t('RAEVO_AI.PAUSE.RESUME')
                  : t('RAEVO_AI.PAUSE.PAUSE')
              "
              @click="togglePause"
            />
          </div>
        </template>

        <template #tabs>
          <TabBar
            data-testid="ai-tabs"
            :tabs="abas"
            :initial-active-tab="indiceDaAba"
            @tab-changed="mudarAba"
          />
        </template>
      </RaevoPageHeader>

      <section
        class="flex items-start gap-3 rounded-xl border border-n-weak bg-n-solid-1 p-4"
        role="status"
      >
        <span
          class="grid size-9 shrink-0 place-items-center rounded-lg bg-n-blue-3 text-n-blue-11"
        >
          <i class="i-lucide-sparkles size-4" aria-hidden="true" />
        </span>
        <div class="min-w-0">
          <h2 class="text-sm font-semibold text-n-slate-12">
            {{ t('RAEVO_AI.NATIVE_AREA.TITLE') }}
          </h2>
          <p class="mt-1 text-sm leading-6 text-n-slate-11">
            {{ t('RAEVO_AI.NATIVE_AREA.DESCRIPTION') }}
          </p>
        </div>
      </section>

      <template v-if="abaAtiva === 'panel'">
        <section
          class="rounded-xl border border-n-weak bg-n-solid-1 p-4 lg:p-5"
        >
          <div>
            <p class="text-micro font-semibold uppercase text-n-slate-10">
              {{ t('RAEVO_AI.OVERVIEW.EYEBROW') }}
            </p>
            <h2 class="mt-1 text-base font-semibold text-n-slate-12">
              {{ t('RAEVO_AI.OVERVIEW.TITLE') }}
            </h2>
          </div>

          <div
            v-if="isLoading"
            class="mt-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-3"
            role="status"
            :aria-label="t('RAEVO_AI.OVERVIEW.LOADING')"
          >
            <div
              v-for="index in 3"
              :key="index"
              class="h-20 animate-pulse rounded-xl bg-n-alpha-2"
            />
          </div>

          <div
            v-else-if="isPreparing"
            data-testid="ai-overview-setup"
            class="mt-4 flex items-start gap-3 rounded-xl border border-n-weak bg-n-alpha-1 p-4"
            role="status"
          >
            <span
              class="grid size-9 shrink-0 place-items-center rounded-lg bg-n-blue-3 text-n-blue-11"
            >
              <i class="i-lucide-settings-2 size-4" aria-hidden="true" />
            </span>
            <div>
              <p class="text-sm font-semibold text-n-slate-12">
                {{ t('RAEVO_AI.OVERVIEW.SETUP.TITLE') }}
              </p>
              <p class="mt-1 text-sm text-n-slate-11">
                {{ t('RAEVO_AI.OVERVIEW.SETUP.DESCRIPTION') }}
              </p>
            </div>
          </div>

          <div
            v-else-if="isDisabled"
            data-testid="ai-overview-disabled"
            class="mt-4 flex items-start gap-3 rounded-xl border border-n-weak bg-n-alpha-1 p-4"
            role="status"
          >
            <span
              class="grid size-9 shrink-0 place-items-center rounded-lg bg-n-amber-3 text-n-amber-11"
            >
              <i class="i-lucide-circle-pause size-4" aria-hidden="true" />
            </span>
            <div>
              <p class="text-sm font-semibold text-n-slate-12">
                {{ t('RAEVO_AI.OVERVIEW.DISABLED.TITLE') }}
              </p>
              <p class="mt-1 text-sm text-n-slate-11">
                {{ t('RAEVO_AI.OVERVIEW.DISABLED.DESCRIPTION') }}
              </p>
            </div>
          </div>

          <div
            v-else-if="hasError"
            data-testid="ai-overview-error"
            class="mt-4 flex flex-col items-start gap-3 rounded-xl border border-n-weak bg-n-alpha-1 p-4 sm:flex-row sm:items-center sm:justify-between"
            role="alert"
          >
            <div>
              <p class="text-sm font-semibold text-n-slate-12">
                {{ t('RAEVO_AI.OVERVIEW.ERROR.TITLE') }}
              </p>
              <p class="mt-1 text-sm text-n-slate-11">
                {{ t('RAEVO_AI.OVERVIEW.ERROR.DESCRIPTION') }}
              </p>
            </div>
            <button
              type="button"
              data-testid="ai-overview-retry"
              class="rounded-full border border-n-strong bg-n-solid-1 px-3 py-2 text-sm font-medium text-n-slate-12 hover:bg-n-alpha-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-brand"
              @click="loadOverview"
            >
              {{ t('RAEVO_AI.OVERVIEW.ERROR.RETRY') }}
            </button>
          </div>

          <div v-else data-testid="ai-overview" class="mt-4">
            <!-- A placa. Existe para responder de relance à única pergunta
                 que a clínica traz ao abrir isto: a Elis está a atender? -->
            <section
              data-testid="ai-plate"
              class="rounded-xl bg-raevo-plate p-4 lg:p-5"
            >
              <h3 class="mt-1 text-xl font-semibold text-raevo-plate-fg">
                {{
                  pauseState?.paused
                    ? t('RAEVO_AI.OVERVIEW.PLATE_PAUSED')
                    : t('RAEVO_AI.OVERVIEW.PLATE_ACTIVE')
                }}
              </h3>
              <p class="mt-1 text-sm text-raevo-plate-muted">
                {{
                  overview?.clinic_name ||
                  t('RAEVO_AI.OVERVIEW.CLINIC_FALLBACK')
                }}
                <span v-if="contractedPackage">
                  {{ ` · ${contractedPackage.title}` }}
                </span>
              </p>

              <div
                data-testid="ai-window-filter"
                class="mt-4 flex flex-wrap gap-1.5"
                role="group"
                :aria-label="t('RAEVO_AI.OVERVIEW.WINDOW_LABEL')"
              >
                <button
                  v-for="dias in windowOptions"
                  :key="dias"
                  type="button"
                  :aria-pressed="windowDays === dias"
                  class="px-3 py-1 text-xs font-medium"
                  :class="
                    windowDays === dias
                      ? 'bg-raevo-plate-fg text-raevo-plate'
                      : 'bg-raevo-plate-soft text-raevo-plate-muted'
                  "
                  @click="changeWindow(dias)"
                >
                  {{ t('RAEVO_AI.OVERVIEW.WINDOW_DAYS', { days: dias }) }}
                </button>
              </div>
            </section>

            <!-- O que precisa de uma pessoa. Vem do registo de comandos do
                 próprio Chatwoot, não do serviço: é dado que já está aqui. -->
            <section
              v-if="activity.attention.failed || activity.attention.pending"
              data-testid="ai-needs-you"
              class="mt-3 rounded-xl border border-n-amber-8 bg-n-amber-2 p-4"
              role="status"
            >
              <p class="text-micro font-semibold uppercase text-n-slate-10">
                {{ t('RAEVO_AI.ACTIVITY.EYEBROW') }}
              </p>
              <ul class="mt-2 flex list-none flex-col gap-1 p-0">
                <li
                  v-if="activity.attention.failed"
                  class="text-sm text-n-slate-12"
                >
                  {{
                    t('RAEVO_AI.ACTIVITY.FAILED', {
                      count: activity.attention.failed,
                    })
                  }}
                </li>
                <li
                  v-if="activity.attention.pending"
                  class="text-sm text-n-slate-12"
                >
                  {{
                    t('RAEVO_AI.ACTIVITY.PENDING', {
                      count: activity.attention.pending,
                    })
                  }}
                </li>
              </ul>
            </section>

            <!-- O que a Elis fez. Vinha da API desde o início e nunca era
                 mostrado: o painel pedia os vinte últimos comandos e deitava-os
                 fora. É o registo do próprio Chatwoot, não do serviço. -->
            <section
              data-testid="ai-activity"
              class="mt-3 rounded-xl border border-n-weak bg-n-solid-1 p-4"
            >
              <h3 class="text-sm font-semibold text-n-slate-12">
                {{ t('RAEVO_AI.ACTIVITY.RECENT_TITLE') }}
              </h3>

              <p
                v-if="!activity.recent.length"
                class="mt-2 text-sm text-n-slate-11"
              >
                {{ t('RAEVO_AI.ACTIVITY.RECENT_EMPTY') }}
              </p>

              <ul v-else class="mt-3 flex list-none flex-col gap-2 p-0">
                <li
                  v-for="item in activity.recent"
                  :key="item.id"
                  data-testid="ai-activity-item"
                  class="flex flex-wrap items-baseline justify-between gap-x-3 gap-y-1 rounded-lg bg-n-alpha-1 px-3 py-2"
                >
                  <span class="text-sm text-n-slate-12">
                    {{ commandLabel(item.command_type) }}
                  </span>
                  <span class="text-xs text-n-slate-10">
                    {{ stateLabel(item.state) }} ·
                    {{ formatMoment(item.occurred_at) }}
                  </span>
                </li>
              </ul>
            </section>

            <p
              v-if="pauseError"
              data-testid="ai-pause-error"
              class="mt-3 text-sm text-n-ruby-11"
              role="alert"
            >
              {{ pauseError }}
            </p>

            <dl class="mt-3 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
              <div
                v-for="metric in overviewMetrics"
                :key="metric.key"
                class="rounded-xl border border-n-weak bg-n-background p-3"
              >
                <dt class="text-xs font-medium text-n-slate-10">
                  {{ metric.label }}
                </dt>
                <dd class="mt-1 text-xl font-semibold text-n-slate-12">
                  {{ displayValue(metric.value) }}
                </dd>
              </div>
            </dl>
          </div>
        </section>
      </template>

      <template v-if="abaAtiva === 'assistant'">
        <section
          class="rounded-xl border border-n-weak bg-n-solid-1 p-4 lg:p-5"
        >
          <div class="max-w-3xl">
            <p class="text-micro font-semibold uppercase text-n-slate-10">
              {{ t('RAEVO_AI.PACKAGES.EYEBROW') }}
            </p>
            <h2 class="mt-1 text-base font-semibold text-n-slate-12">
              {{ t('RAEVO_AI.PACKAGES.TITLE') }}
            </h2>
          </div>

          <article
            v-if="contractedPackage"
            data-testid="ai-service-package"
            class="mt-4 rounded-xl border border-n-weak bg-n-background p-4"
          >
            <span
              class="grid size-9 place-items-center rounded-lg bg-n-blue-3 text-n-blue-11"
            >
              <i
                :class="contractedPackage.icon"
                class="size-4"
                aria-hidden="true"
              />
            </span>
            <h3 class="mt-3 break-words text-sm font-semibold text-n-slate-12">
              {{ contractedPackage.title }}
            </h3>
            <p class="mt-1 text-sm leading-6 text-n-slate-11">
              {{ contractedPackage.description }}
            </p>

            <ul
              v-if="activeCapabilities.length"
              data-testid="ai-capabilities"
              class="mt-4 grid list-none gap-2 p-0 sm:grid-cols-2"
            >
              <li
                v-for="capability in activeCapabilities"
                :key="capability.id"
                class="rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2"
              >
                <p class="text-sm font-medium text-n-slate-12">
                  {{ capability.label }}
                </p>
                <p
                  v-if="capability.provider"
                  class="mt-0.5 text-xs text-n-slate-10"
                >
                  {{ capability.provider }}
                </p>
              </li>
            </ul>
          </article>

          <p
            v-else
            data-testid="ai-service-package-empty"
            class="mt-4 text-sm text-n-slate-11"
          >
            {{ t('RAEVO_AI.PACKAGES.EMPTY') }}
          </p>
        </section>

        <RaevoAiServiceHoursSettings v-if="isAdmin" />
      </template>

      <RaevoAiKnowledgePanel
        v-if="abaAtiva === 'knowledge'"
        :is-admin="isAdmin"
      />
    </div>
  </main>
</template>
