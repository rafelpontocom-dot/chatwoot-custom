<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

import { getKanbanNextActionState } from 'dashboard/helper/kanbanNextAction';
import {
  getKanbanStageColorOption,
  isNeutralStageColor,
} from 'dashboard/helper/kanbanStageColors';

const props = defineProps({
  stages: {
    type: Array,
    default: () => [],
  },
  selectedCardIds: {
    type: Array,
    default: () => [],
  },
  stageCardsLoading: {
    type: Object,
    default: () => ({}),
  },
  stageCardsErrors: {
    type: Object,
    default: () => ({}),
  },
  // O vazio quase sempre é filtro a mais. Sem saber se há filtros ativos, a
  // lista só podia dizer «não há nada» — que é verdade e não ajuda.
  hasActiveFilters: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits([
  'openDetails',
  'openConversation',
  'toggleSelection',
  'toggleVisibleSelection',
  'loadMoreStageCards',
  'clearFilters',
  'openFilters',
]);
const { t } = useI18n();

const rows = computed(() =>
  props.stages.flatMap(stage =>
    (stage.cards || []).map(card => ({
      ...card,
      stageName: stage.name,
      stageColor: stage.color,
    }))
  )
);
const stagesWithMore = computed(() =>
  props.stages.filter(stage => stage.pagination?.hasMore)
);
const visibleCardIds = computed(() => rows.value.map(card => card.id));
const selectedVisibleCardCount = computed(
  () =>
    visibleCardIds.value.filter(cardId =>
      props.selectedCardIds.includes(cardId)
    ).length
);
const hasSelectedVisibleCards = computed(
  () => selectedVisibleCardCount.value > 0
);
const allVisibleCardsSelected = computed(
  () =>
    visibleCardIds.value.length > 0 &&
    selectedVisibleCardCount.value === visibleCardIds.value.length
);

const contactName = card =>
  card.contact?.name ||
  card.contact?.email ||
  card.contact?.phone_number ||
  t('KANBAN.CARD.UNKNOWN_CONTACT');

const ownerName = card =>
  card.owner?.name || card.assignee?.name || t('KANBAN.CARD.UNASSIGNED');

const amount = card => {
  const amountCents = card.amountCents ?? card.amount_cents;
  if (amountCents === null || amountCents === undefined || amountCents === '') {
    return t('KANBAN.LIST.NO_VALUE');
  }

  const cents = Number(amountCents);
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: card.amountCurrency || card.amount_currency || 'BRL',
  }).format(cents / 100);
};

// A mesma tabela de estados do cartão do quadro. A próxima ação é o que se vem
// cá procurar, e comunicá-la só por cor de texto reprovava na regra 5.
const nextActionState = card =>
  getKanbanNextActionState(
    card.nextActionStatus || card.next_action_status || ''
  ) || getKanbanNextActionState('missing');

const nextAction = card =>
  card.nextActionType ||
  card.next_action_type ||
  t(nextActionState(card).labelKey);

// A etapa tem cor no quadro e na gaveta. Perdê-la aqui obrigava a ler o que
// noutro sítio se reconhecia.
const stageChipClass = card =>
  getKanbanStageColorOption(card.stageColor).softClass;

const stageDotClass = card =>
  isNeutralStageColor(card.stageColor)
    ? 'bg-n-slate-8'
    : getKanbanStageColorOption(card.stageColor).dotClass;

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
    class="min-h-0 flex-1 overflow-auto p-3 lg:p-6"
  >
    <div class="overflow-hidden rounded-lg border border-n-weak bg-n-solid-1">
      <div
        class="hidden grid-cols-[2.5rem_minmax(16rem,1.5fr)_minmax(8rem,0.75fr)_minmax(8rem,0.75fr)_minmax(9rem,0.9fr)_minmax(9rem,0.8fr)_2.5rem] items-center gap-3 border-b border-n-weak bg-n-surface-2 px-4 py-3 text-xs font-medium text-n-slate-11 md:grid"
      >
        <input
          type="checkbox"
          data-testid="kanban-list-select-visible"
          :checked="allVisibleCardsSelected"
          :indeterminate="hasSelectedVisibleCards && !allVisibleCardsSelected"
          :aria-label="t('KANBAN.LIST.SELECT_VISIBLE')"
          class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
          @change="
            emit(
              'toggleVisibleSelection',
              visibleCardIds,
              $event.target.checked
            )
          "
        />
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
          class="grid grid-cols-[2rem_minmax(0,1fr)] items-center gap-2 px-3 py-3 text-sm hover:bg-n-alpha-1 md:grid-cols-[2.5rem_minmax(16rem,1.5fr)_minmax(8rem,0.75fr)_minmax(8rem,0.75fr)_minmax(9rem,0.9fr)_minmax(9rem,0.8fr)_2.5rem] md:gap-3 md:px-4"
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
            class="min-w-0 text-left outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-n-brand/40"
            @click="emit('openDetails', card)"
          >
            <!--
              Duas linhas, não uma cortada. O AGENTS.md proíbe que título de
              oportunidade dependa de `truncate` para caber, e numa lista de
              comparação é pior: compara-se o que não se lê. A altura fica
              estável porque o limite são duas linhas, não um comprimento
              qualquer.
            -->
            <span
              class="block break-words font-medium leading-snug text-n-slate-12 line-clamp-2"
              >{{ card.subject || contactName(card) }}</span
            >
            <span class="block truncate text-xs text-n-slate-11">
              {{ contactName(card) }}
              {{ t('KANBAN.OVERVIEW.SEPARATOR') }}
              {{ lastActivity(card) }}
            </span>
          </button>
          <span
            class="col-start-2 flex min-w-0 items-center justify-between gap-3 text-n-slate-11 md:col-auto md:block"
          >
            <span class="text-xs text-n-slate-10 md:hidden">
              {{ t('KANBAN.LIST.STAGE') }}
            </span>
            <span
              class="inline-flex min-w-0 max-w-full items-start gap-1.5 rounded-full px-2 py-0.5 text-xs font-medium leading-snug text-n-slate-12"
              :class="stageChipClass(card)"
            >
              <span
                class="mt-1 size-1.5 shrink-0 rounded-full"
                :class="stageDotClass(card)"
                aria-hidden="true"
              />
              <span class="break-words">{{ card.stageName }}</span>
            </span>
          </span>
          <span
            class="col-start-2 flex min-w-0 items-center justify-between gap-3 font-medium text-n-slate-12 md:col-auto md:block"
          >
            <span class="text-xs font-normal text-n-slate-10 md:hidden">
              {{ t('KANBAN.LIST.VALUE') }}
            </span>
            <span class="truncate">{{ amount(card) }}</span>
          </span>
          <span
            class="col-start-2 flex min-w-0 items-center justify-between gap-3 md:col-auto md:block"
          >
            <span class="text-xs text-n-slate-10 md:hidden">
              {{ t('KANBAN.LIST.NEXT_ACTION') }}
            </span>
            <span
              class="inline-flex min-w-0 max-w-full items-start gap-1.5 rounded-full px-2 py-0.5 text-xs font-medium leading-snug"
              :class="nextActionState(card).class"
            >
              <i
                class="mt-0.5 size-3 shrink-0"
                :class="nextActionState(card).icon"
                aria-hidden="true"
              />
              <span class="break-words">{{ nextAction(card) }}</span>
            </span>
          </span>
          <span
            class="col-start-2 flex min-w-0 items-center justify-between gap-3 text-n-slate-11 md:col-auto md:block"
          >
            <span class="text-xs text-n-slate-10 md:hidden">
              {{ t('KANBAN.LIST.OWNER') }}
            </span>
            <span class="truncate">{{ ownerName(card) }}</span>
          </span>
          <button
            v-if="card.conversationId || card.conversation_id"
            type="button"
            class="col-start-2 flex p-0 size-8 items-center justify-center self-end justify-self-end rounded-md text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40 md:col-auto md:self-auto"
            :aria-label="t('KANBAN.LIST.OPEN')"
            :title="t('KANBAN.LIST.OPEN')"
            @click="emit('openConversation', card)"
          >
            <i class="i-lucide-arrow-up-right size-4" />
          </button>
        </article>
      </div>

      <div
        v-else
        data-testid="kanban-list-empty"
        class="flex flex-col items-center gap-1 p-8 text-center"
      >
        <span
          class="mb-1 grid size-10 place-items-center rounded-md bg-n-alpha-1 text-n-slate-11"
        >
          <i class="i-lucide-package-open size-5" aria-hidden="true" />
        </span>
        <b class="text-base font-medium text-n-slate-12">
          {{
            hasActiveFilters
              ? t('KANBAN.LIST.EMPTY_FILTERED')
              : t('KANBAN.LIST.EMPTY')
          }}
        </b>
        <p class="mb-0 max-w-prose text-sm text-n-slate-11">
          {{
            hasActiveFilters
              ? t('KANBAN.LIST.EMPTY_FILTERED_HINT')
              : t('KANBAN.LIST.EMPTY_HINT')
          }}
        </p>
        <!--
          Só aparece com filtros ativos: oferecer «Limpar filtros» quando não há
          filtro nenhum é prometer uma saída que não existe.
        -->
        <div
          v-if="hasActiveFilters"
          class="mt-2 flex flex-wrap justify-center gap-2"
        >
          <button
            type="button"
            data-testid="kanban-list-clear-filters"
            class="flex h-8 items-center rounded-lg bg-n-brand px-2.5 text-sm font-medium text-white outline-none focus-visible:ring-2 focus-visible:ring-n-brand/40"
            @click="emit('clearFilters')"
          >
            {{ t('KANBAN.LIST.CLEAR_FILTERS') }}
          </button>
          <button
            type="button"
            data-testid="kanban-list-review-filters"
            class="flex h-8 items-center rounded-lg border border-solid border-n-weak px-2.5 text-sm font-medium text-n-slate-12 outline-none hover:bg-n-alpha-1 focus-visible:ring-2 focus-visible:ring-n-brand/40"
            @click="emit('openFilters')"
          >
            {{ t('KANBAN.LIST.REVIEW_FILTERS') }}
          </button>
        </div>
      </div>
    </div>
    <div v-if="stagesWithMore.length" class="mt-3 grid gap-2">
      <div
        v-for="stage in stagesWithMore"
        :key="stage.id"
        class="flex flex-wrap items-center justify-between gap-2 rounded-md border border-n-weak bg-n-surface-2 px-3 py-2"
      >
        <span class="text-xs text-n-slate-11">
          {{ stage.name }}
          {{ t('KANBAN.OVERVIEW.SEPARATOR') }}
          {{ stage.cardsCount || stage.cards?.length || 0 }}
        </span>
        <button
          type="button"
          class="rounded-md px-2.5 py-1.5 text-xs font-medium text-n-brand outline-none hover:bg-n-alpha-2 focus:ring-2 focus:ring-n-brand/40 disabled:cursor-wait disabled:opacity-60"
          :data-testid="`kanban-list-load-more-${stage.id}`"
          :disabled="stageCardsLoading[stage.id]"
          @click="emit('loadMoreStageCards', stage)"
        >
          {{
            stageCardsLoading[stage.id]
              ? t('KANBAN.LIST.LOADING_MORE')
              : t('KANBAN.ACTIONS.LOAD_MORE_CARDS')
          }}
        </button>
        <p
          v-if="stageCardsErrors[stage.id]"
          class="basis-full mb-0 text-xs text-n-ruby-11"
          role="alert"
        >
          {{ stageCardsErrors[stage.id] }}
        </p>
      </div>
    </div>
    <p class="mb-0 mt-3 text-xs text-n-slate-10">
      {{ t('KANBAN.LIST.PAGINATION_NOTE') }}
    </p>
  </section>
</template>
