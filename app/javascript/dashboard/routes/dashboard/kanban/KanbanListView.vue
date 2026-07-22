<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  stages: {
    type: Array,
    default: () => [],
  },
  selectedCardIds: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits([
  'openDetails',
  'openConversation',
  'toggleSelection',
]);
const { t } = useI18n();

const rows = computed(() =>
  props.stages.flatMap(stage =>
    (stage.cards || []).map(card => ({ ...card, stageName: stage.name }))
  )
);

const contactName = card =>
  card.contact?.name ||
  card.contact?.email ||
  card.contact?.phone_number ||
  t('KANBAN.CARD.UNKNOWN_CONTACT');

const ownerName = card =>
  card.owner?.name || card.assignee?.name || t('KANBAN.CARD.UNASSIGNED');

const amount = card => {
  const cents = Number(card.amountCents ?? card.amount_cents ?? 0);
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: card.amountCurrency || card.amount_currency || 'BRL',
  }).format(cents / 100);
};

const nextAction = card => {
  if (!card.nextActionAt && !card.nextActionType) {
    return t('KANBAN.CARD.NEXT_ACTION.MISSING');
  }

  return card.nextActionType || t('KANBAN.CARD.NEXT_ACTION.FUTURE');
};

const nextActionClass = card => {
  if (card.nextActionStatus === 'overdue') return 'text-n-ruby-11';
  if (card.nextActionStatus === 'due_today') return 'text-n-amber-11';
  return 'text-n-slate-11';
};

const lastActivity = card =>
  card.lastActivityAt || card.last_activity_at
    ? new Date(
        card.lastActivityAt || card.last_activity_at
      ).toLocaleDateString()
    : t('KANBAN.CARD.UNKNOWN_LAST_ACTIVITY');
</script>

<template>
  <section
    data-testid="kanban-list-view"
    class="min-h-0 flex-1 overflow-auto p-4 lg:p-6"
  >
    <div
      class="min-w-[48rem] overflow-hidden rounded-lg border border-n-weak bg-n-solid-1"
    >
      <div
        class="grid grid-cols-[2.5rem_minmax(16rem,1.5fr)_minmax(8rem,0.75fr)_minmax(8rem,0.75fr)_minmax(9rem,0.9fr)_minmax(9rem,0.8fr)_2.5rem] items-center gap-3 border-b border-n-weak bg-n-surface-2 px-4 py-3 text-xs font-medium text-n-slate-11"
      >
        <span class="sr-only">{{ t('KANBAN.LIST.SELECT') }}</span>
        <span>{{ t('KANBAN.LIST.OPPORTUNITY') }}</span>
        <span>{{ t('KANBAN.LIST.STAGE') }}</span>
        <span>{{ t('KANBAN.LIST.VALUE') }}</span>
        <span>{{ t('KANBAN.LIST.NEXT_ACTION') }}</span>
        <span>{{ t('KANBAN.LIST.OWNER') }}</span>
        <span class="sr-only">{{ t('KANBAN.LIST.ACTIONS') }}</span>
      </div>

      <div v-if="rows.length" class="divide-y divide-n-weak">
        <article
          v-for="card in rows"
          :key="card.id"
          :data-testid="`kanban-list-row-${card.id}`"
          class="grid grid-cols-[2.5rem_minmax(16rem,1.5fr)_minmax(8rem,0.75fr)_minmax(8rem,0.75fr)_minmax(9rem,0.9fr)_minmax(9rem,0.8fr)_2.5rem] items-center gap-3 px-4 py-3 text-sm hover:bg-n-alpha-1"
        >
          <input
            type="checkbox"
            :checked="selectedCardIds.includes(card.id)"
            :aria-label="
              t('KANBAN.LIST.SELECT_OPPORTUNITY', { name: contactName(card) })
            "
            class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
            @change="emit('toggleSelection', card, $event.target.checked)"
          />
          <button
            type="button"
            class="min-w-0 text-left"
            @click="emit('openDetails', card)"
          >
            <span class="block truncate font-medium text-n-slate-12">{{
              card.subject || contactName(card)
            }}</span>
            <span class="block truncate text-xs text-n-slate-11">
              {{ contactName(card) }}
              {{ t('KANBAN.OVERVIEW.SEPARATOR') }}
              {{ lastActivity(card) }}
            </span>
          </button>
          <span class="truncate text-n-slate-11">{{ card.stageName }}</span>
          <span class="truncate font-medium text-n-slate-12">{{
            amount(card)
          }}</span>
          <span class="truncate" :class="nextActionClass(card)">{{
            nextAction(card)
          }}</span>
          <span class="truncate text-n-slate-11">{{ ownerName(card) }}</span>
          <button
            type="button"
            class="flex size-8 items-center justify-center rounded-md text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12"
            :aria-label="t('KANBAN.LIST.OPEN')"
            :title="t('KANBAN.LIST.OPEN')"
            @click="emit('openConversation', card)"
          >
            <i class="i-lucide-arrow-up-right size-4" />
          </button>
        </article>
      </div>

      <p v-else class="mb-0 p-8 text-center text-sm text-n-slate-11">
        {{ t('KANBAN.LIST.EMPTY') }}
      </p>
    </div>
    <p class="mb-0 mt-3 text-xs text-n-slate-10">
      {{ t('KANBAN.LIST.PAGINATION_NOTE') }}
    </p>
  </section>
</template>
