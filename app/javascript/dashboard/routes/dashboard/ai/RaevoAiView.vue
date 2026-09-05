<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAdmin } from 'dashboard/composables/useAdmin';
import KanbanBoardsAPI from 'dashboard/api/kanbanBoards';
import RaevoPageHeader from 'dashboard/components-next/raevo/RaevoPageHeader.vue';
import RaevoField from 'dashboard/components-next/raevo/RaevoField.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import RaevoAiAPI from 'dashboard/api/raevoAi';

const { t } = useI18n();
const overview = ref(null);
const isLoading = ref(true);
const hasError = ref(false);
const { isAdmin } = useAdmin();
const aiTabConfiguration = ref({ enabled: false, board_ids: [] });
const aiTabBoardOptions = ref([]);
const isLoadingAiTabConfiguration = ref(false);
const isSavingAiTabConfiguration = ref(false);
const aiTabConfigurationError = ref(false);

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
]);

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

  try {
    const { data } = await RaevoAiAPI.get();
    overview.value = data;
  } catch {
    overview.value = null;
    hasError.value = true;
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
  <main class="mx-auto flex w-full max-w-[96rem] flex-col gap-4 p-4 lg:p-6">
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
          class="rounded-lg border border-n-strong bg-n-solid-1 px-3 py-2 text-sm font-medium text-n-slate-12 hover:bg-n-alpha-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-n-brand"
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
            <i :class="servicePackage.icon" class="size-4" aria-hidden="true" />
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
  </main>
</template>
