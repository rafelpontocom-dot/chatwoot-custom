<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAdmin } from 'dashboard/composables/useAdmin';
import KanbanBoardsAPI from 'dashboard/api/kanbanBoards';
import RaevoPageHeader from 'dashboard/components-next/raevo/RaevoPageHeader.vue';
import RaevoField from 'dashboard/components-next/raevo/RaevoField.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import RaevoAiAPI from 'dashboard/api/raevoAi';
import RaevoAiServiceHoursSettings from './RaevoAiServiceHoursSettings.vue';

const { t } = useI18n();
const overview = ref(null);
const isLoading = ref(true);
const hasError = ref(false);
const isPreparing = ref(false);
const isPaused = ref(false);
const { isAdmin } = useAdmin();
const aiTabConfiguration = ref({ enabled: false, board_ids: [] });
const aiTabBoardOptions = ref([]);
const isLoadingAiTabConfiguration = ref(false);
const isSavingAiTabConfiguration = ref(false);
const aiTabConfigurationError = ref(false);
const assistantDraft = ref(null);
const activeAssistantVersion = ref(null);
const isLoadingAssistantDraft = ref(false);
const isSavingAssistantDraft = ref(false);
const assistantDraftError = ref(null);
const isSimulatingAssistantDraft = ref(false);
const assistantDraftSimulation = ref(null);
const assistantDraftSimulationError = ref(null);
const assistantDraftSimulationFixtureId = ref(null);
const assistantDraftReview = ref(null);
const isReviewingAssistantDraft = ref(false);
const assistantDraftReviewError = ref(null);
const isPublishingAssistantDraft = ref(false);
const assistantDraftPublication = ref(null);
const assistantDraftPublicationError = ref(null);
const assistantDraftPublicationConfirmed = ref(false);
const emptyAssistantDraftClusters = () => ({
  identity: { enabled: true, content: '' },
  personality: { enabled: true, content: '' },
  voice_style: { enabled: true, content: '' },
});
const assistantDraftClusters = ref(emptyAssistantDraftClusters());
const assistantDraftFields = computed(() => [
  { key: 'identity', label: t('RAEVO_AI.ASSISTANT_DRAFT.FIELDS.IDENTITY') },
  {
    key: 'personality',
    label: t('RAEVO_AI.ASSISTANT_DRAFT.FIELDS.PERSONALITY'),
  },
  {
    key: 'voice_style',
    label: t('RAEVO_AI.ASSISTANT_DRAFT.FIELDS.VOICE_STYLE'),
  },
]);

const usage = computed(() => overview.value?.usage_30d || {});
const formatTokens = value =>
  Number.isFinite(Number(value))
    ? new Intl.NumberFormat('en-US').format(Number(value))
    : '—';
const formatUsd = value => `US$ ${Number(value || 0).toFixed(2)}`;
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
    label: t('RAEVO_AI.OVERVIEW.METRICS.CONVERSATIONS'),
    value: overview.value?.usage_30d?.conversations,
  },
  {
    key: 'HANDOFFS',
    label: t('RAEVO_AI.OVERVIEW.METRICS.HANDOFFS'),
    value: overview.value?.usage_30d?.handoffs,
  },
  {
    key: 'APPOINTMENTS',
    label: t('RAEVO_AI.OVERVIEW.METRICS.APPOINTMENTS'),
    value: overview.value?.usage_30d?.appointments,
  },
  {
    key: 'PAYMENTS',
    label: t('RAEVO_AI.OVERVIEW.METRICS.PAYMENTS'),
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
    label: t('RAEVO_AI.OVERVIEW.METRICS.TOKENS'),
    value: formatTokens(
      Number(usage.value.prompt_tokens || 0) +
        Number(usage.value.completion_tokens || 0)
    ),
  },
  {
    key: 'COST',
    label: t('RAEVO_AI.OVERVIEW.METRICS.COST'),
    value: usageCost.value,
  },
]);
const assistantProfileFields = computed(() => {
  const profile = overview.value?.assistant_profile || {};
  return [
    {
      key: 'IDENTITY',
      label: t('RAEVO_AI.OVERVIEW.ASSISTANT_PROFILE.IDENTITY'),
      value: profile.identity,
    },
    {
      key: 'PERSONALITY',
      label: t('RAEVO_AI.OVERVIEW.ASSISTANT_PROFILE.PERSONALITY'),
      value: profile.personality,
    },
    {
      key: 'VOICE_STYLE',
      label: t('RAEVO_AI.OVERVIEW.ASSISTANT_PROFILE.VOICE_STYLE'),
      value: profile.voice_style,
    },
  ].filter(field => typeof field.value === 'string' && field.value.trim());
});
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
const operationalQualityItems = computed(() => {
  const quality = overview.value?.operational_quality || {};
  return [
    {
      key: 'post_delivery_actions_pending',
      label: t('RAEVO_AI.QUALITY.POST_DELIVERY_ACTIONS_PENDING'),
      value: quality.post_delivery_actions_pending,
    },
    {
      key: 'post_delivery_actions_applied',
      label: t('RAEVO_AI.QUALITY.POST_DELIVERY_ACTIONS_APPLIED'),
      value: quality.post_delivery_actions_applied,
    },
    {
      key: 'post_delivery_actions_failed',
      label: t('RAEVO_AI.QUALITY.POST_DELIVERY_ACTIONS_FAILED'),
      value: quality.post_delivery_actions_failed,
    },
    {
      key: 'manual_reconciliations',
      label: t('RAEVO_AI.QUALITY.MANUAL_RECONCILIATIONS'),
      value: quality.manual_reconciliations,
    },
  ].filter(item => Number(item.value) > 0);
});
const operationalQualityAttention = computed(() => {
  const quality = overview.value?.operational_quality || {};
  const level = quality.attention_level;
  const attentionLevelLabels = {
    clear: t('RAEVO_AI.QUALITY.ATTENTION_LEVELS.CLEAR'),
    investigate: t('RAEVO_AI.QUALITY.ATTENTION_LEVELS.INVESTIGATE'),
    action_required: t('RAEVO_AI.QUALITY.ATTENTION_LEVELS.ACTION_REQUIRED'),
  };
  if (!attentionLevelLabels[level]) return null;

  const attentionReasonLabels = {
    post_delivery_actions_failed: t(
      'RAEVO_AI.QUALITY.ATTENTION_REASONS.POST_DELIVERY_ACTIONS_FAILED'
    ),
    post_delivery_actions_pending: t(
      'RAEVO_AI.QUALITY.ATTENTION_REASONS.POST_DELIVERY_ACTIONS_PENDING'
    ),
    manual_reconciliations: t(
      'RAEVO_AI.QUALITY.ATTENTION_REASONS.MANUAL_RECONCILIATIONS'
    ),
  };
  const reasons = Array.isArray(quality.attention_reasons)
    ? quality.attention_reasons.filter(reason =>
        Object.hasOwn(attentionReasonLabels, reason)
      )
    : [];

  return {
    label: attentionLevelLabels[level],
    reasons: reasons.map(reason => attentionReasonLabels[reason]),
  };
});

const displayValue = value => value ?? '—';
const selectedAiTabBoardIds = computed({
  get: () => aiTabConfiguration.value.board_ids.map(String),
  set: boardIds => {
    aiTabConfiguration.value = {
      ...aiTabConfiguration.value,
      board_ids: boardIds.map(Number),
    };
  },
});

const loadOverview = async () => {
  isLoading.value = true;
  hasError.value = false;
  isPreparing.value = false;
  isPaused.value = false;

  try {
    const { data } = await RaevoAiAPI.get();
    const connectionState = data?.connection_state;
    overview.value = connectionState ? data.overview : data;
    isPreparing.value = connectionState === 'not_configured';
    isPaused.value = connectionState === 'paused';
    hasError.value = connectionState === 'unavailable';
  } catch (error) {
    overview.value = null;
    isPreparing.value = error?.response?.status === 404;
    hasError.value = !isPreparing.value;
  } finally {
    isLoading.value = false;
  }
};

onMounted(loadOverview);

const normalizeCollection = response => {
  const data = response?.data;
  if (Array.isArray(data)) return data;
  if (Array.isArray(data?.payload)) return data.payload;
  return [];
};
const loadAiTabConfiguration = async () => {
  if (!isAdmin.value) return;

  isLoadingAiTabConfiguration.value = true;
  aiTabConfigurationError.value = false;
  try {
    const [{ data }, boardsResponse] = await Promise.all([
      RaevoAiAPI.getOpportunityTab(),
      KanbanBoardsAPI.getBoards(),
    ]);
    aiTabConfiguration.value = {
      enabled: data?.enabled === true,
      board_ids: Array(data?.board_ids).map(Number),
    };
    aiTabBoardOptions.value = normalizeCollection(boardsResponse).map(
      board => ({
        id: Number(board.id),
        name: board.name,
      })
    );
  } catch {
    aiTabConfigurationError.value = true;
  } finally {
    isLoadingAiTabConfiguration.value = false;
  }
};
const saveAiTabConfiguration = async () => {
  isSavingAiTabConfiguration.value = true;
  aiTabConfigurationError.value = false;
  try {
    const { data } = await RaevoAiAPI.updateOpportunityTab({
      enabled: aiTabConfiguration.value.enabled,
      board_ids: aiTabConfiguration.value.board_ids,
    });
    aiTabConfiguration.value = {
      enabled: data.enabled === true,
      board_ids: Array(data.board_ids).map(Number),
    };
  } catch {
    aiTabConfigurationError.value = true;
  } finally {
    isSavingAiTabConfiguration.value = false;
  }
};

onMounted(loadAiTabConfiguration);

const normalizeAssistantDraftClusters = clusters => {
  const defaults = emptyAssistantDraftClusters();
  return Object.keys(defaults).reduce((normalized, key) => {
    const cluster = clusters?.[key] || {};
    normalized[key] = {
      enabled: cluster.enabled !== false,
      content: typeof cluster.content === 'string' ? cluster.content : '',
    };
    return normalized;
  }, {});
};
const loadAssistantDraft = async () => {
  if (!isAdmin.value) return;

  isLoadingAssistantDraft.value = true;
  assistantDraftError.value = null;
  try {
    const { data } = await RaevoAiAPI.getAssistantDraft();
    assistantDraft.value = data?.draft || null;
    activeAssistantVersion.value = data?.active_version || null;
    assistantDraftClusters.value = normalizeAssistantDraftClusters(
      data?.draft?.editable_clusters
    );
  } catch {
    assistantDraftError.value = 'unavailable';
  } finally {
    isLoadingAssistantDraft.value = false;
  }
};
const saveAssistantDraft = async () => {
  isSavingAssistantDraft.value = true;
  assistantDraftError.value = null;
  try {
    const { data } = await RaevoAiAPI.saveAssistantDraft({
      expected_revision: assistantDraft.value?.revision || null,
      editable_clusters: assistantDraftClusters.value,
    });
    assistantDraft.value = data?.draft || null;
    if (data?.draft?.editable_clusters) {
      assistantDraftClusters.value = normalizeAssistantDraftClusters(
        data.draft.editable_clusters
      );
    }
  } catch (error) {
    assistantDraftError.value =
      error?.response?.status === 409 ? 'conflict' : 'unavailable';
  } finally {
    isSavingAssistantDraft.value = false;
  }
};

const assistantDraftSimulationFixtures = computed(() => [
  {
    id: 'first_contact',
    label: t('RAEVO_AI.ASSISTANT_SIMULATION.FIXTURES.FIRST_CONTACT'),
  },
  {
    id: 'scheduling_intent',
    label: t('RAEVO_AI.ASSISTANT_SIMULATION.FIXTURES.SCHEDULING_INTENT'),
  },
  {
    id: 'human_request',
    label: t('RAEVO_AI.ASSISTANT_SIMULATION.FIXTURES.HUMAN_REQUEST'),
  },
]);
const runAssistantDraftSimulation = async fixtureId => {
  if (!assistantDraft.value?.id) {
    assistantDraftSimulationError.value = 'draft_required';
    return;
  }

  isSimulatingAssistantDraft.value = true;
  assistantDraftSimulationError.value = null;
  assistantDraftSimulation.value = null;
  assistantDraftSimulationFixtureId.value = null;
  assistantDraftReview.value = null;
  assistantDraftReviewError.value = null;
  assistantDraftPublication.value = null;
  assistantDraftPublicationError.value = null;
  assistantDraftPublicationConfirmed.value = false;
  try {
    const { data } = await RaevoAiAPI.simulateAssistantDraft({
      draft_id: assistantDraft.value.id,
      fixture_id: fixtureId,
    });
    assistantDraftSimulation.value = data;
    assistantDraftSimulationFixtureId.value = fixtureId;
  } catch {
    assistantDraftSimulationError.value = 'unavailable';
  } finally {
    isSimulatingAssistantDraft.value = false;
  }
};

const canReviewAssistantDraft = computed(
  () =>
    assistantDraftSimulation.value?.evaluation?.verdict ===
      'ready_for_human_review' &&
    assistantDraft.value?.id &&
    assistantDraft.value?.revision &&
    assistantDraftSimulationFixtureId.value
);
const canPublishAssistantDraft = computed(
  () =>
    assistantDraftReview.value?.id &&
    assistantDraft.value?.id &&
    assistantDraft.value?.revision &&
    activeAssistantVersion.value?.id
);
const reviewAssistantDraft = async () => {
  if (!canReviewAssistantDraft.value) return;

  isReviewingAssistantDraft.value = true;
  assistantDraftReviewError.value = null;
  try {
    const { data } = await RaevoAiAPI.reviewAssistantDraft({
      draft_id: assistantDraft.value.id,
      fixture_id: assistantDraftSimulationFixtureId.value,
      expected_revision: assistantDraft.value.revision,
      decision: 'approved',
    });
    assistantDraftReview.value = data?.review || null;
  } catch (error) {
    assistantDraftReviewError.value =
      error?.response?.status === 409 ? 'conflict' : 'unavailable';
  } finally {
    isReviewingAssistantDraft.value = false;
  }
};
const publishAssistantDraft = async () => {
  if (
    !canPublishAssistantDraft.value ||
    !assistantDraftPublicationConfirmed.value
  )
    return;

  isPublishingAssistantDraft.value = true;
  assistantDraftPublicationError.value = null;
  try {
    const { data } = await RaevoAiAPI.publishAssistantDraft({
      draft_id: assistantDraft.value.id,
      expected_revision: assistantDraft.value.revision,
      expected_active_version_id: activeAssistantVersion.value.id,
      review_id: assistantDraftReview.value.id,
    });
    assistantDraftPublication.value = data?.publication || null;
  } catch (error) {
    assistantDraftPublicationError.value =
      error?.response?.status === 409 ? 'conflict' : 'unavailable';
  } finally {
    isPublishingAssistantDraft.value = false;
  }
};

onMounted(loadAssistantDraft);

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
      />

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

      <section class="rounded-xl border border-n-weak bg-n-solid-1 p-4 lg:p-5">
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
          v-else-if="isPaused"
          data-testid="ai-overview-paused"
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
              {{ t('RAEVO_AI.OVERVIEW.PAUSED.TITLE') }}
            </p>
            <p class="mt-1 text-sm text-n-slate-11">
              {{ t('RAEVO_AI.OVERVIEW.PAUSED.DESCRIPTION') }}
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
          <div class="flex flex-wrap items-center gap-2">
            <p class="text-sm font-semibold text-n-slate-12">
              {{
                overview?.clinic_name || t('RAEVO_AI.OVERVIEW.CLINIC_FALLBACK')
              }}
            </p>
            <span
              class="rounded-full bg-n-teal-3 px-2 py-0.5 text-xs font-medium text-n-teal-11"
            >
              {{ overview?.status || t('RAEVO_AI.OVERVIEW.STATUS_UNKNOWN') }}
            </span>
            <span v-if="overview?.package" class="text-xs text-n-slate-10">
              {{ overview.package }}
            </span>
          </div>

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

          <section
            v-if="assistantProfileFields.length"
            data-testid="ai-assistant-profile"
            class="mt-4 rounded-xl border border-n-weak bg-n-background p-4"
          >
            <p class="text-micro font-semibold uppercase text-n-slate-10">
              {{ t('RAEVO_AI.OVERVIEW.ASSISTANT_PROFILE.EYEBROW') }}
            </p>
            <h3 class="mt-1 text-sm font-semibold text-n-slate-12">
              {{ t('RAEVO_AI.OVERVIEW.ASSISTANT_PROFILE.TITLE') }}
            </h3>
            <dl class="mt-3 grid gap-3 lg:grid-cols-3">
              <div v-for="field in assistantProfileFields" :key="field.key">
                <dt class="text-xs font-medium text-n-slate-10">
                  {{ field.label }}
                </dt>
                <dd class="mt-1 text-sm leading-6 text-n-slate-12">
                  {{ field.value }}
                </dd>
              </div>
            </dl>
          </section>

          <section
            v-if="activeCapabilities.length"
            data-testid="ai-capabilities"
            class="mt-4 rounded-xl border border-n-weak bg-n-background p-4"
          >
            <p class="text-micro font-semibold uppercase text-n-slate-10">
              {{ t('RAEVO_AI.CAPABILITIES.EYEBROW') }}
            </p>
            <h3 class="mt-1 text-sm font-semibold text-n-slate-12">
              {{ t('RAEVO_AI.CAPABILITIES.TITLE') }}
            </h3>
            <p class="mt-1 text-sm leading-6 text-n-slate-11">
              {{ t('RAEVO_AI.CAPABILITIES.DESCRIPTION') }}
            </p>
            <ul class="mt-3 grid gap-2 sm:grid-cols-2 lg:grid-cols-4">
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
          </section>

          <section
            v-if="operationalQualityItems.length"
            data-testid="ai-operational-quality"
            class="mt-4 rounded-xl border border-n-weak bg-n-background p-4"
          >
            <div class="flex items-start gap-3">
              <span
                class="grid size-9 shrink-0 place-items-center rounded-lg bg-n-amber-3 text-n-amber-11"
              >
                <i class="i-lucide-search-check size-4" aria-hidden="true" />
              </span>
              <div>
                <p class="text-micro font-semibold uppercase text-n-slate-10">
                  {{ t('RAEVO_AI.QUALITY.EYEBROW') }}
                </p>
                <h3 class="mt-1 text-sm font-semibold text-n-slate-12">
                  {{ t('RAEVO_AI.QUALITY.TITLE') }}
                </h3>
                <p class="mt-1 text-sm leading-6 text-n-slate-11">
                  {{ t('RAEVO_AI.QUALITY.DESCRIPTION') }}
                </p>
                <p
                  v-if="operationalQualityAttention"
                  data-testid="ai-operational-quality-attention"
                  class="mt-3 flex items-start gap-2 rounded-lg bg-n-slate-3 px-3 py-2 text-sm text-n-slate-11"
                  role="status"
                >
                  <i
                    class="i-lucide-circle-alert mt-0.5 size-4 shrink-0 text-n-slate-12"
                    aria-hidden="true"
                  />
                  <span>
                    {{ operationalQualityAttention.label }}
                    <span v-if="operationalQualityAttention.reasons.length">
                      {{ t('RAEVO_AI.QUALITY.ATTENTION_SEPARATOR') }}
                      {{
                        operationalQualityAttention.reasons.join(
                          ` ${t('RAEVO_AI.QUALITY.ATTENTION_SEPARATOR')} `
                        )
                      }}
                    </span>
                  </span>
                </p>
              </div>
            </div>
            <dl class="mt-3 grid gap-2 sm:grid-cols-3">
              <div
                v-for="item in operationalQualityItems"
                :key="item.key"
                class="rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2"
              >
                <dt class="text-xs text-n-slate-10">{{ item.label }}</dt>
                <dd class="mt-1 text-xl font-semibold text-n-slate-12">
                  {{ item.value }}
                </dd>
              </div>
            </dl>
          </section>
        </div>
      </section>

      <section
        v-if="isAdmin"
        data-testid="ai-assistant-simulation"
        class="rounded-xl border border-n-weak bg-n-solid-1 p-4 lg:p-5"
      >
        <div class="max-w-3xl">
          <p class="text-micro font-semibold uppercase text-n-slate-10">
            {{ t('RAEVO_AI.ASSISTANT_SIMULATION.EYEBROW') }}
          </p>
          <h2 class="mt-1 text-base font-semibold text-n-slate-12">
            {{ t('RAEVO_AI.ASSISTANT_SIMULATION.TITLE') }}
          </h2>
          <p class="mt-1 text-sm leading-6 text-n-slate-11">
            {{ t('RAEVO_AI.ASSISTANT_SIMULATION.DESCRIPTION') }}
          </p>
        </div>

        <div
          class="mt-4 flex flex-wrap gap-2"
          role="group"
          :aria-label="t('RAEVO_AI.ASSISTANT_SIMULATION.FIXTURES_LABEL')"
        >
          <NextButton
            v-for="fixture in assistantDraftSimulationFixtures"
            :key="fixture.id"
            type="button"
            :data-testid="`ai-assistant-simulation-${fixture.id}`"
            :label="fixture.label"
            :disabled="isSimulatingAssistantDraft || !assistantDraft?.id"
            :is-loading="isSimulatingAssistantDraft"
            @click="runAssistantDraftSimulation(fixture.id)"
          />
        </div>

        <p
          v-if="
            !assistantDraft?.id ||
            assistantDraftSimulationError === 'draft_required'
          "
          class="mt-3 flex items-center gap-2 text-sm text-n-amber-11"
          role="status"
        >
          <i class="i-lucide-save size-4" aria-hidden="true" />
          {{ t('RAEVO_AI.ASSISTANT_SIMULATION.DRAFT_REQUIRED') }}
        </p>
        <p
          v-else-if="assistantDraftSimulationError === 'unavailable'"
          class="mt-3 flex items-center gap-2 text-sm text-n-ruby-11"
          role="alert"
        >
          <i class="i-lucide-circle-alert size-4" aria-hidden="true" />
          {{ t('RAEVO_AI.ASSISTANT_SIMULATION.ERROR') }}
        </p>

        <div
          v-if="assistantDraftSimulation?.simulation"
          data-testid="ai-assistant-simulation-result"
          class="mt-4 rounded-xl border border-n-weak bg-n-background p-4"
        >
          <div class="flex items-start gap-3">
            <span
              class="grid size-9 shrink-0 place-items-center rounded-lg bg-n-blue-3 text-n-blue-11"
            >
              <i class="i-lucide-flask-conical size-4" aria-hidden="true" />
            </span>
            <div class="min-w-0">
              <p class="text-sm font-semibold text-n-slate-12">
                {{ t('RAEVO_AI.ASSISTANT_SIMULATION.RESULT_TITLE') }}
              </p>
              <p class="mt-1 text-sm text-n-slate-11">
                {{ t('RAEVO_AI.ASSISTANT_SIMULATION.REVIEW_ONLY') }}
              </p>
            </div>
          </div>
          <div class="mt-3 grid gap-2">
            <p
              v-for="(bubble, index) in assistantDraftSimulation.simulation
                .response_bubbles"
              :key="`${index}-${bubble}`"
              class="rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2 text-sm leading-6 text-n-slate-12"
            >
              {{ bubble }}
            </p>
          </div>
          <p class="mt-3 text-xs text-n-slate-10">
            {{
              t('RAEVO_AI.ASSISTANT_SIMULATION.VERDICT', {
                verdict:
                  assistantDraftSimulation.evaluation?.verdict || 'blocked',
              })
            }}
          </p>

          <div
            v-if="canReviewAssistantDraft"
            class="mt-4 border-t border-n-weak pt-4"
          >
            <p class="text-sm font-medium text-n-slate-12">
              {{ t('RAEVO_AI.ASSISTANT_SIMULATION.REVIEW_TITLE') }}
            </p>
            <p class="mt-1 text-sm text-n-slate-11">
              {{ t('RAEVO_AI.ASSISTANT_SIMULATION.REVIEW_DESCRIPTION') }}
            </p>
            <NextButton
              v-if="!assistantDraftReview?.id"
              type="button"
              data-testid="ai-assistant-draft-review"
              class="mt-3"
              :label="t('RAEVO_AI.ASSISTANT_SIMULATION.APPROVE_REVIEW')"
              :is-loading="isReviewingAssistantDraft"
              :disabled="isReviewingAssistantDraft"
              @click="reviewAssistantDraft"
            />
            <p
              v-else
              class="mt-3 flex items-center gap-2 text-sm text-n-teal-11"
              role="status"
            >
              <i class="i-lucide-circle-check size-4" aria-hidden="true" />
              {{ t('RAEVO_AI.ASSISTANT_SIMULATION.REVIEW_APPROVED') }}
            </p>
            <p
              v-if="assistantDraftReviewError"
              class="mt-3 flex items-center gap-2 text-sm text-n-ruby-11"
              role="alert"
            >
              <i class="i-lucide-circle-alert size-4" aria-hidden="true" />
              {{ t('RAEVO_AI.ASSISTANT_SIMULATION.REVIEW_ERROR') }}
            </p>
          </div>

          <div
            v-if="canPublishAssistantDraft"
            class="mt-4 border-t border-n-weak pt-4"
          >
            <p class="text-sm font-medium text-n-slate-12">
              {{ t('RAEVO_AI.ASSISTANT_SIMULATION.PUBLICATION_TITLE') }}
            </p>
            <p class="mt-1 text-sm text-n-slate-11">
              {{ t('RAEVO_AI.ASSISTANT_SIMULATION.PUBLICATION_DESCRIPTION') }}
            </p>
            <label class="mt-3 flex items-start gap-2 text-sm text-n-slate-11">
              <input
                v-model="assistantDraftPublicationConfirmed"
                data-testid="ai-assistant-draft-publication-confirmation"
                type="checkbox"
                :disabled="
                  isPublishingAssistantDraft || assistantDraftPublication?.id
                "
                class="mt-0.5 size-4 rounded border-n-strong text-n-brand focus:ring-n-brand"
              />
              <span>{{
                t('RAEVO_AI.ASSISTANT_SIMULATION.PUBLICATION_CONFIRMATION')
              }}</span>
            </label>
            <NextButton
              v-if="!assistantDraftPublication?.id"
              type="button"
              data-testid="ai-assistant-draft-publish"
              class="mt-3"
              :label="t('RAEVO_AI.ASSISTANT_SIMULATION.PUBLISH')"
              :is-loading="isPublishingAssistantDraft"
              :disabled="
                isPublishingAssistantDraft ||
                !assistantDraftPublicationConfirmed
              "
              @click="publishAssistantDraft"
            />
            <p
              v-else
              class="mt-3 flex items-center gap-2 text-sm text-n-teal-11"
              role="status"
            >
              <i class="i-lucide-circle-check size-4" aria-hidden="true" />
              {{ t('RAEVO_AI.ASSISTANT_SIMULATION.PUBLICATION_SUCCEEDED') }}
            </p>
            <p
              v-if="assistantDraftPublicationError"
              class="mt-3 flex items-center gap-2 text-sm text-n-ruby-11"
              role="alert"
            >
              <i class="i-lucide-circle-alert size-4" aria-hidden="true" />
              {{ t('RAEVO_AI.ASSISTANT_SIMULATION.PUBLICATION_ERROR') }}
            </p>
          </div>
        </div>
      </section>

      <RaevoAiServiceHoursSettings v-if="isAdmin" />

      <section
        v-if="isAdmin"
        data-testid="ai-assistant-draft"
        class="rounded-xl border border-n-weak bg-n-solid-1 p-4 lg:p-5"
      >
        <div class="max-w-3xl">
          <p class="text-micro font-semibold uppercase text-n-slate-10">
            {{ t('RAEVO_AI.ASSISTANT_DRAFT.EYEBROW') }}
          </p>
          <h2 class="mt-1 text-base font-semibold text-n-slate-12">
            {{ t('RAEVO_AI.ASSISTANT_DRAFT.TITLE') }}
          </h2>
          <p class="mt-1 text-sm leading-6 text-n-slate-11">
            {{ t('RAEVO_AI.ASSISTANT_DRAFT.DESCRIPTION') }}
          </p>
          <p v-if="activeAssistantVersion" class="mt-2 text-xs text-n-slate-10">
            {{
              t('RAEVO_AI.ASSISTANT_DRAFT.ACTIVE_VERSION', {
                version: activeAssistantVersion.version_number,
              })
            }}
          </p>
        </div>

        <p
          v-if="assistantDraftError === 'conflict'"
          data-testid="ai-assistant-draft-conflict"
          class="mt-4 flex items-center gap-2 text-sm text-n-amber-11"
          role="alert"
        >
          <i class="i-lucide-refresh-cw size-4" aria-hidden="true" />
          {{ t('RAEVO_AI.ASSISTANT_DRAFT.CONFLICT') }}
        </p>
        <p
          v-else-if="assistantDraftError === 'unavailable'"
          data-testid="ai-assistant-draft-error"
          class="mt-4 flex items-center gap-2 text-sm text-n-ruby-11"
          role="alert"
        >
          <i class="i-lucide-circle-alert size-4" aria-hidden="true" />
          {{ t('RAEVO_AI.ASSISTANT_DRAFT.ERROR') }}
        </p>

        <div v-if="isLoadingAssistantDraft" class="mt-4" role="status">
          <p class="text-sm text-n-slate-11">
            {{ t('RAEVO_AI.ASSISTANT_DRAFT.LOADING') }}
          </p>
        </div>

        <div v-else class="mt-4 grid max-w-3xl gap-4">
          <RaevoField
            v-for="field in assistantDraftFields"
            :key="field.key"
            :label="field.label"
          >
            <template #default="{ controlClass, fieldId }">
              <div :data-testid="`ai-assistant-draft-${field.key}`">
                <textarea
                  :id="fieldId"
                  v-model="assistantDraftClusters[field.key].content"
                  class="min-h-24 resize-y rounded-lg"
                  :class="controlClass"
                  :disabled="isSavingAssistantDraft"
                  maxlength="500"
                  rows="3"
                />
                <label
                  class="mt-2 flex items-center gap-2 text-sm text-n-slate-11"
                >
                  <input
                    v-model="assistantDraftClusters[field.key].enabled"
                    type="checkbox"
                    :disabled="isSavingAssistantDraft"
                    class="size-4 rounded border-n-strong text-n-brand focus:ring-n-brand"
                  />
                  {{ t('RAEVO_AI.ASSISTANT_DRAFT.ENABLED') }}
                </label>
              </div>
            </template>
          </RaevoField>

          <div class="flex flex-wrap items-center gap-3">
            <NextButton
              type="button"
              data-testid="ai-assistant-draft-save"
              :label="t('RAEVO_AI.ASSISTANT_DRAFT.SAVE')"
              :is-loading="isSavingAssistantDraft"
              :disabled="isSavingAssistantDraft"
              @click="saveAssistantDraft"
            />
            <p class="text-xs text-n-slate-10">
              {{ t('RAEVO_AI.ASSISTANT_DRAFT.DRAFT_ONLY') }}
            </p>
          </div>
        </div>
      </section>

      <section
        v-if="isAdmin"
        data-testid="ai-opportunity-tab-configuration"
        class="rounded-xl border border-n-weak bg-n-solid-1 p-4 lg:p-5"
      >
        <div class="max-w-3xl">
          <p class="text-micro font-semibold uppercase text-n-slate-10">
            {{ t('RAEVO_AI.OPPORTUNITY.SETTINGS.EYEBROW') }}
          </p>
          <h2 class="mt-1 text-base font-semibold text-n-slate-12">
            {{ t('RAEVO_AI.OPPORTUNITY.SETTINGS.TITLE') }}
          </h2>
          <p class="mt-1 text-sm leading-6 text-n-slate-11">
            {{ t('RAEVO_AI.OPPORTUNITY.SETTINGS.DESCRIPTION') }}
          </p>
        </div>

        <p
          v-if="aiTabConfigurationError"
          class="mt-4 text-sm text-n-ruby-11"
          role="alert"
        >
          {{ t('RAEVO_AI.OPPORTUNITY.SETTINGS.ERROR') }}
        </p>

        <div v-else class="mt-4 grid gap-4 max-w-2xl">
          <RaevoField
            :label="t('RAEVO_AI.OPPORTUNITY.SETTINGS.BOARDS')"
            variant="select"
          >
            <template #default="{ controlClass, fieldId }">
              <select
                :id="fieldId"
                v-model="selectedAiTabBoardIds"
                multiple
                :disabled="
                  isLoadingAiTabConfiguration || isSavingAiTabConfiguration
                "
                class="min-h-32"
                :class="[controlClass]"
              >
                <option
                  v-for="board in aiTabBoardOptions"
                  :key="board.id"
                  :value="String(board.id)"
                >
                  {{ board.name }}
                </option>
              </select>
            </template>
          </RaevoField>

          <label class="flex items-start gap-3 text-sm text-n-slate-12">
            <input
              v-model="aiTabConfiguration.enabled"
              type="checkbox"
              :disabled="
                isLoadingAiTabConfiguration || isSavingAiTabConfiguration
              "
              class="mt-0.5 size-4 rounded border-n-strong text-n-brand focus:ring-n-brand"
            />
            <span>
              <span class="block font-medium">{{
                t('RAEVO_AI.OPPORTUNITY.SETTINGS.ENABLED')
              }}</span>
              <span class="mt-0.5 block text-n-slate-11">{{
                t('RAEVO_AI.OPPORTUNITY.SETTINGS.ENABLED_HINT')
              }}</span>
            </span>
          </label>

          <div>
            <NextButton
              type="button"
              data-testid="ai-opportunity-tab-save"
              :label="t('RAEVO_AI.OPPORTUNITY.SETTINGS.SAVE')"
              :is-loading="isSavingAiTabConfiguration"
              :disabled="isLoadingAiTabConfiguration"
              @click="saveAiTabConfiguration"
            />
          </div>
        </div>
      </section>

      <section class="rounded-xl border border-n-weak bg-n-solid-1 p-4 lg:p-5">
        <div class="max-w-3xl">
          <p class="text-micro font-semibold uppercase text-n-slate-10">
            {{ t('RAEVO_AI.PACKAGES.EYEBROW') }}
          </p>
          <h2 class="mt-1 text-base font-semibold text-n-slate-12">
            {{ t('RAEVO_AI.PACKAGES.TITLE') }}
          </h2>
          <p class="mt-1 text-sm leading-6 text-n-slate-11">
            {{ t('RAEVO_AI.PACKAGES.DESCRIPTION') }}
          </p>
        </div>

        <div class="mt-4 grid gap-3 lg:grid-cols-3">
          <article
            v-for="servicePackage in servicePackages"
            :key="servicePackage.key"
            data-testid="ai-service-package"
            class="rounded-xl border border-n-weak bg-n-background p-4"
          >
            <span
              class="grid size-9 place-items-center rounded-lg bg-n-blue-3 text-n-blue-11"
            >
              <i
                :class="servicePackage.icon"
                class="size-4"
                aria-hidden="true"
              />
            </span>
            <h3 class="mt-3 break-words text-sm font-semibold text-n-slate-12">
              {{ servicePackage.title }}
            </h3>
            <p class="mt-1 text-sm leading-6 text-n-slate-11">
              {{ servicePackage.description }}
            </p>
          </article>
        </div>
      </section>
    </div>
  </main>
</template>
