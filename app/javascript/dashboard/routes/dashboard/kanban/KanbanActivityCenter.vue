<script setup>
import { computed, onMounted, onUnmounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import camelcaseKeys from 'camelcase-keys';

import KanbanBoardsAPI from 'dashboard/api/kanbanBoards';

const props = defineProps({
  stages: {
    type: Array,
    default: () => [],
  },
  boardId: {
    type: [Number, String],
    default: null,
  },
  ownerOptions: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['close', 'openDetails']);
const { t } = useI18n();
const activeView = ref('today');
const activityCloseButton = ref(null);
const remoteCards = ref([]);
const isLoadingActivities = ref(false);
const activityError = ref('');
const activityPage = ref(1);
const activityHasMore = ref(false);
const selectedOwnerId = ref('');

const cards = computed(() =>
  props.boardId
    ? remoteCards.value
    : props.stages.flatMap(stage =>
        (stage.cards || []).map(card => ({ ...card, stageName: stage.name }))
      )
);

const loadActivities = async ({ append = false } = {}) => {
  if (!props.boardId || isLoadingActivities.value) return;

  const page = append ? activityPage.value + 1 : 1;
  isLoadingActivities.value = true;
  activityError.value = '';

  try {
    const response = await KanbanBoardsAPI.getActivities(props.boardId, {
      params: {
        view: activeView.value,
        page,
        limit: 25,
        ...(selectedOwnerId.value ? { owner_id: selectedOwnerId.value } : {}),
      },
    });
    const payload = camelcaseKeys(response.data || {}, { deep: true });
    const nextCards = payload.cards || [];

    remoteCards.value = append
      ? [...remoteCards.value, ...nextCards]
      : nextCards;
    activityPage.value = page;
    activityHasMore.value = Boolean(payload.pagination?.hasMore);
  } catch (error) {
    activityError.value =
      error?.response?.data?.message || t('KANBAN.ACTIVITY.LOAD_ERROR');
  } finally {
    isLoadingActivities.value = false;
  }
};

const actionDate = card => {
  const value = card.nextActionAt || card.next_action_at;
  return value ? new Date(value) : null;
};

const appointmentDate = card => {
  const value = card.startsAt || card.starts_at;
  return value ? new Date(value) : null;
};

const isToday = card => {
  const date = actionDate(card);
  const now = new Date();
  return (
    date &&
    date.getFullYear() === now.getFullYear() &&
    date.getMonth() === now.getMonth() &&
    date.getDate() === now.getDate()
  );
};

const isOverdue = card =>
  card.nextActionStatus === 'overdue' ||
  card.next_action_status === 'overdue' ||
  (actionDate(card) && actionDate(card) < new Date() && !isToday(card));

const hasAction = card =>
  Boolean(actionDate(card) || card.nextActionType || card.next_action_type);

const hasAppointment = card => Boolean(appointmentDate(card));

const actionCards = computed(() => {
  if (activeView.value === 'today') return cards.value.filter(isToday);
  if (activeView.value === 'overdue') return cards.value.filter(isOverdue);
  if (activeView.value === 'upcoming') {
    return cards.value.filter(card => {
      const date = actionDate(card);
      return date && date > new Date() && !isToday(card);
    });
  }
  if (activeView.value === 'missing') {
    return cards.value.filter(card => !hasAction(card));
  }
  if (activeView.value === 'appointments') {
    const startOfToday = new Date();
    startOfToday.setHours(0, 0, 0, 0);
    return cards.value.filter(card => {
      const date = appointmentDate(card);
      return (
        date &&
        date >= startOfToday &&
        !card.wonAt &&
        !card.won_at &&
        !card.lostAt &&
        !card.lost_at
      );
    });
  }
  return cards.value;
});

const ownerGroups = computed(() => {
  const groups = new Map();
  const cardsForOwners = selectedOwnerId.value
    ? cards.value.filter(
        card =>
          String(card.ownerId || card.owner_id || '') ===
          String(selectedOwnerId.value)
      )
    : cards.value;

  cardsForOwners.forEach(card => {
    const owner =
      card.owner?.name || card.assignee?.name || t('KANBAN.CARD.UNASSIGNED');
    const group = groups.get(owner) || [];
    group.push(card);
    groups.set(owner, group);
  });
  return [...groups.entries()].map(([name, groupCards]) => ({
    name,
    cards: groupCards,
  }));
});

const visibleCards = computed(() => {
  const filteredCards = selectedOwnerId.value
    ? cards.value.filter(
        card =>
          String(card.ownerId || card.owner_id || '') ===
          String(selectedOwnerId.value)
      )
    : cards.value;

  if (activeView.value === 'owner') {
    return ownerGroups.value.flatMap(group => group.cards);
  }

  return props.boardId
    ? filteredCards
    : actionCards.value.filter(card => filteredCards.includes(card));
});

const cardTitle = card =>
  card.subject || card.contact?.name || t('KANBAN.CARD.UNKNOWN_CONTACT');
const cardDate = card => {
  const date =
    activeView.value === 'appointments'
      ? appointmentDate(card)
      : actionDate(card);
  return date ? date.toLocaleString() : t('KANBAN.ACTIVITY.NO_DATE');
};
const ownerName = card =>
  card.owner?.name || card.assignee?.name || t('KANBAN.CARD.UNASSIGNED');
const activityTabs = computed(() => [
  { key: 'today', label: t('KANBAN.ACTIVITY.TODAY') },
  { key: 'overdue', label: t('KANBAN.ACTIVITY.OVERDUE') },
  { key: 'upcoming', label: t('KANBAN.ACTIVITY.UPCOMING') },
  { key: 'missing', label: t('KANBAN.ACTIVITY.MISSING') },
  { key: 'appointments', label: t('KANBAN.ACTIVITY.APPOINTMENTS') },
  { key: 'owner', label: t('KANBAN.ACTIVITY.BY_OWNER') },
]);

const handleActivityKeydown = event => {
  if (event.key !== 'Escape') return;

  event.preventDefault();
  emit('close');
};

const trapActivityFocus = event => {
  if (event.key !== 'Tab') return;

  const focusableElements = [
    ...event.currentTarget.querySelectorAll(
      'button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [href]'
    ),
  ];
  if (!focusableElements.length) return;

  const firstElement = focusableElements[0];
  const lastElement = focusableElements[focusableElements.length - 1];

  if (event.shiftKey && document.activeElement === firstElement) {
    event.preventDefault();
    lastElement.focus();
  } else if (!event.shiftKey && document.activeElement === lastElement) {
    event.preventDefault();
    firstElement.focus();
  }
};

onMounted(() => {
  activityCloseButton.value?.focus();
  window.addEventListener('keydown', handleActivityKeydown);
  loadActivities();
});

watch([activeView, selectedOwnerId], () => loadActivities());

onUnmounted(() => {
  window.removeEventListener('keydown', handleActivityKeydown);
});
</script>

<template>
  <div
    data-testid="kanban-activity-center"
    class="fixed inset-0 z-[60] flex justify-end bg-black/30"
    role="dialog"
    aria-modal="true"
    :aria-label="t('KANBAN.ACTIVITY.TITLE')"
  >
    <button
      type="button"
      class="absolute inset-0 cursor-default"
      :aria-label="t('KANBAN.ACTIONS.CLOSE')"
      @click="emit('close')"
    />
    <aside
      class="relative flex h-full w-full max-w-[34rem] flex-col bg-n-background shadow-xl"
      @keydown="trapActivityFocus"
    >
      <header
        class="flex items-start justify-between gap-3 border-b border-n-weak px-5 py-4"
      >
        <div>
          <p
            class="mb-1 text-xs font-medium uppercase tracking-wide text-n-slate-10"
          >
            {{ t('KANBAN.ACTIVITY.LABEL') }}
          </p>
          <h2 class="mb-0 text-lg font-semibold text-n-slate-12">
            {{ t('KANBAN.ACTIVITY.TITLE') }}
          </h2>
        </div>
        <button
          ref="activityCloseButton"
          type="button"
          class="flex size-9 items-center justify-center rounded-md text-n-slate-11 outline-none hover:bg-n-alpha-2 focus:ring-2 focus:ring-n-brand/40"
          :aria-label="t('KANBAN.ACTIONS.CLOSE')"
          @click="emit('close')"
        >
          <i class="i-lucide-x size-4" />
        </button>
      </header>

      <nav
        class="flex gap-1 overflow-x-auto border-b border-n-weak px-5"
        :aria-label="t('KANBAN.ACTIVITY.TABS_LABEL')"
        role="tablist"
      >
        <button
          v-for="item in activityTabs"
          :key="item.key"
          type="button"
          :data-testid="`kanban-activity-tab-${item.key}`"
          class="whitespace-nowrap border-b-2 px-2.5 py-3 text-sm font-medium outline-none focus:ring-2 focus:ring-inset focus:ring-n-brand/40"
          role="tab"
          :aria-selected="activeView === item.key"
          :class="
            activeView === item.key
              ? 'border-n-brand text-n-brand'
              : 'border-transparent text-n-slate-11 hover:text-n-slate-12'
          "
          @click="activeView = item.key"
        >
          {{ item.label }}
        </button>
      </nav>

      <div class="flex items-center gap-2 border-b border-n-weak px-5 py-3">
        <label
          for="kanban-activity-owner-filter"
          class="flex-none text-xs font-medium text-n-slate-11"
        >
          {{ t('KANBAN.ACTIVITY.OWNER_FILTER') }}
        </label>
        <select
          id="kanban-activity-owner-filter"
          v-model="selectedOwnerId"
          data-testid="kanban-activity-owner-filter"
          class="min-w-0 flex-1 rounded-md border border-n-weak bg-n-surface-1 px-2 py-1.5 text-sm text-n-slate-12 outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
          :disabled="!ownerOptions.length"
        >
          <option value="">{{ t('KANBAN.ACTIVITY.ALL_OWNERS') }}</option>
          <option
            v-for="owner in ownerOptions"
            :key="owner.value"
            :value="String(owner.value)"
          >
            {{ owner.label }}
          </option>
        </select>
      </div>

      <div class="min-h-0 flex-1 overflow-y-auto p-5">
        <template v-if="isLoadingActivities && !visibleCards.length">
          <p
            data-testid="kanban-activity-loading"
            class="mb-0 p-5 text-center text-sm text-n-slate-11"
          >
            {{ t('KANBAN.ACTIVITY.LOADING') }}
          </p>
        </template>
        <template v-else-if="activityError && !visibleCards.length">
          <p
            data-testid="kanban-activity-error"
            class="mb-0 p-5 text-center text-sm text-n-ruby-11"
            role="alert"
          >
            {{ activityError }}
          </p>
          <button
            type="button"
            class="mx-auto mt-3 flex items-center rounded-md border border-n-weak px-3 py-2 text-sm font-medium text-n-slate-11 outline-none hover:bg-n-alpha-2 focus:ring-2 focus:ring-n-brand/40"
            :aria-label="t('KANBAN.ACTIONS.RETRY')"
            @click="loadActivities()"
          >
            {{ t('KANBAN.ACTIONS.RETRY') }}
          </button>
        </template>
        <template v-else>
          <div
            v-if="activityError"
            data-testid="kanban-activity-error"
            class="mb-3 flex items-center justify-between gap-3 rounded-md border border-n-ruby-7 bg-n-ruby-1 px-3 py-2 text-sm text-n-ruby-11"
            role="alert"
          >
            <span>{{ activityError }}</span>
            <button
              type="button"
              class="flex-none rounded-md px-2 py-1 font-medium outline-none hover:bg-n-ruby-2 focus:ring-2 focus:ring-n-ruby-8"
              :aria-label="t('KANBAN.ACTIONS.RETRY')"
              @click="loadActivities({ append: true })"
            >
              {{ t('KANBAN.ACTIONS.RETRY') }}
            </button>
          </div>
          <div v-if="activeView === 'owner'" class="grid gap-3">
            <section
              v-for="group in ownerGroups"
              :key="group.name"
              class="grid gap-2 rounded-lg border border-n-weak p-3"
            >
              <div class="flex items-center justify-between gap-2">
                <h3 class="mb-0 text-sm font-semibold text-n-slate-12">
                  {{ group.name }}
                </h3>
                <span class="text-xs text-n-slate-10">{{
                  group.cards.length
                }}</span>
              </div>
              <button
                v-for="card in group.cards"
                :key="card.id"
                type="button"
                class="flex items-center justify-between gap-3 rounded-md px-2 py-2 text-left outline-none hover:bg-n-alpha-2 focus:ring-2 focus:ring-inset focus:ring-n-brand/40"
                @click="emit('openDetails', card)"
              >
                <span class="min-w-0 truncate text-sm text-n-slate-12">
                  {{ cardTitle(card) }}
                </span>
                <span class="flex-none text-xs text-n-slate-10">
                  {{ card.stageName }}
                </span>
              </button>
            </section>
          </div>

          <div v-else-if="visibleCards.length" class="grid gap-2">
            <button
              v-for="card in visibleCards"
              :key="card.id"
              type="button"
              :data-testid="`kanban-activity-card-${card.id}`"
              class="grid gap-1 rounded-lg border border-n-weak p-3 text-left outline-none hover:border-n-brand hover:bg-n-alpha-1 focus:ring-2 focus:ring-inset focus:ring-n-brand/40"
              @click="emit('openDetails', card)"
            >
              <span class="truncate text-sm font-medium text-n-slate-12">
                {{ cardTitle(card) }}
              </span>
              <span class="truncate text-xs text-n-slate-11">
                {{ card.stageName }}
                {{ t('KANBAN.OVERVIEW.SEPARATOR') }}
                {{ ownerName(card) }}
              </span>
              <span class="text-xs text-n-slate-10">
                <template
                  v-if="activeView === 'appointments' && hasAppointment(card)"
                >
                  {{ t('KANBAN.ACTIVITY.APPOINTMENT') }}
                  {{ t('KANBAN.OVERVIEW.SEPARATOR') }}
                  {{ cardDate(card) }}
                </template>
                <template v-else>
                  {{
                    hasAction(card)
                      ? `${
                          card.nextActionType ||
                          card.next_action_type ||
                          t('KANBAN.ACTIVITY.NEXT_ACTION')
                        } ${t('KANBAN.OVERVIEW.SEPARATOR')} ${cardDate(card)}`
                      : t('KANBAN.ACTIVITY.NO_DATE')
                  }}
                </template>
              </span>
            </button>
          </div>
          <p
            v-else
            class="mb-0 rounded-lg border border-dashed border-n-weak p-5 text-center text-sm text-n-slate-11"
          >
            {{ t('KANBAN.ACTIVITY.EMPTY') }}
          </p>
          <button
            v-if="activityHasMore && !isLoadingActivities"
            type="button"
            data-testid="kanban-activity-load-more"
            class="mt-3 flex w-full items-center justify-center rounded-md border border-n-weak px-3 py-2 text-sm font-medium text-n-slate-11 outline-none hover:bg-n-alpha-2 focus:ring-2 focus:ring-n-brand/40"
            @click="loadActivities({ append: true })"
          >
            {{ t('KANBAN.ACTIVITY.LOAD_MORE') }}
          </button>
        </template>
      </div>
    </aside>
  </div>
</template>
