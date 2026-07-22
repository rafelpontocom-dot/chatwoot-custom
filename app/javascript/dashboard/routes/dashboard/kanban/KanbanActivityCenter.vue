<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  stages: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['close', 'openDetails']);
const { t } = useI18n();
const activeView = ref('today');

const cards = computed(() =>
  props.stages.flatMap(stage =>
    (stage.cards || []).map(card => ({ ...card, stageName: stage.name }))
  )
);

const actionDate = card => {
  const value = card.nextActionAt || card.next_action_at;
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
  return cards.value;
});

const ownerGroups = computed(() => {
  const groups = new Map();
  cards.value.forEach(card => {
    const owner =
      card.owner?.name || card.assignee?.name || t('KANBAN.CARD.UNASSIGNED');
    const group = groups.get(owner) || [];
    group.push(card);
    groups.set(owner, group);
  });
  return [...groups.entries()].map(([name, ownerCards]) => ({
    name,
    cards: ownerCards,
  }));
});

const visibleCards = computed(() =>
  activeView.value === 'owner'
    ? ownerGroups.value.flatMap(group => group.cards)
    : actionCards.value
);

const cardTitle = card =>
  card.subject || card.contact?.name || t('KANBAN.CARD.UNKNOWN_CONTACT');
const cardDate = card => {
  const date = actionDate(card);
  return date ? date.toLocaleString() : t('KANBAN.ACTIVITY.NO_DATE');
};
const ownerName = card =>
  card.owner?.name || card.assignee?.name || t('KANBAN.CARD.UNASSIGNED');
const activityTabs = computed(() => [
  { key: 'today', label: t('KANBAN.ACTIVITY.TODAY') },
  { key: 'overdue', label: t('KANBAN.ACTIVITY.OVERDUE') },
  { key: 'upcoming', label: t('KANBAN.ACTIVITY.UPCOMING') },
  { key: 'missing', label: t('KANBAN.ACTIVITY.MISSING') },
  { key: 'owner', label: t('KANBAN.ACTIVITY.BY_OWNER') },
]);
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
          type="button"
          class="flex size-9 items-center justify-center rounded-md text-n-slate-11 hover:bg-n-alpha-2"
          :aria-label="t('KANBAN.ACTIONS.CLOSE')"
          @click="emit('close')"
        >
          <i class="i-lucide-x size-4" />
        </button>
      </header>

      <nav
        class="flex gap-1 overflow-x-auto border-b border-n-weak px-5"
        :aria-label="t('KANBAN.ACTIVITY.TABS_LABEL')"
      >
        <button
          v-for="item in activityTabs"
          :key="item.key"
          type="button"
          :data-testid="`kanban-activity-tab-${item.key}`"
          class="whitespace-nowrap border-b-2 px-2.5 py-3 text-sm font-medium"
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

      <div class="min-h-0 flex-1 overflow-y-auto p-5">
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
              class="flex items-center justify-between gap-3 rounded-md px-2 py-2 text-left hover:bg-n-alpha-2"
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
            class="grid gap-1 rounded-lg border border-n-weak p-3 text-left hover:border-n-brand hover:bg-n-alpha-1"
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
              {{
                hasAction(card)
                  ? `${
                      card.nextActionType ||
                      card.next_action_type ||
                      t('KANBAN.ACTIVITY.NEXT_ACTION')
                    } ${t('KANBAN.OVERVIEW.SEPARATOR')} ${cardDate(card)}`
                  : t('KANBAN.ACTIVITY.NO_DATE')
              }}
            </span>
          </button>
        </div>
        <p
          v-else
          class="mb-0 rounded-lg border border-dashed border-n-weak p-5 text-center text-sm text-n-slate-11"
        >
          {{ t('KANBAN.ACTIVITY.EMPTY') }}
        </p>
      </div>
    </aside>
  </div>
</template>
