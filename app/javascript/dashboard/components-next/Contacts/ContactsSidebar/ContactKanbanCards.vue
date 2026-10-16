<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import KanbanBoardsAPI from 'dashboard/api/kanbanBoards';
import { useMapGetter } from 'dashboard/composables/store';
import {
  DEFAULT_CURRENCY,
  intlLocale,
} from 'dashboard/composables/useAccountCurrency';

import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Button from 'dashboard/components-next/button/Button.vue';
// RAEVO (09/10, 123jpnbcb5n): criar a oportunidade sem sair do contato.
import KanbanContactOpportunityDialog from 'dashboard/routes/dashboard/kanban/KanbanContactOpportunityDialog.vue';

const props = defineProps({
  contactId: {
    type: [Number, String],
    required: true,
  },
});

const { t, locale } = useI18n();
const route = useRoute();
const router = useRouter();

const cards = ref([]);
const isLoading = ref(false);
const hasError = ref(false);
const abortController = ref(null);
const requestId = ref(0);

const hasCards = computed(() => cards.value.length > 0);

const getContactById = useMapGetter('contacts/getContactById');
const contactName = computed(
  () => getContactById.value(props.contactId)?.name || ''
);
const novaOportunidade = ref(null);
const abrirNovaOportunidade = () => novaOportunidade.value?.open();

const normalizeCollection = response =>
  response.data?.payload || response.data || [];

const isAbortError = error =>
  error?.name === 'AbortError' || error?.name === 'CanceledError';

const abortCurrentRequest = () => {
  abortController.value?.abort();
  abortController.value = null;
};

// RAEVO (09/10, 123jpnbcb5n): a linha da maquete — onde está, quanto vale e
// quando se espera fechar. A previsão é só data: lida em UTC, que é o dia
// gravado (o mesmo cuidado do 5d na ficha).
const formatAmount = card =>
  card.amount_cents === null || card.amount_cents === undefined
    ? ''
    : new Intl.NumberFormat(intlLocale(locale?.value), {
        style: 'currency',
        currency: card.amount_currency || DEFAULT_CURRENCY,
      }).format(card.amount_cents / 100);
const formatCloseDate = value =>
  new Intl.DateTimeFormat(undefined, {
    dateStyle: 'short',
    timeZone: 'UTC',
  }).format(new Date(value));

const loadCards = async () => {
  if (!props.contactId) return;

  abortCurrentRequest();
  const currentRequestId = requestId.value + 1;
  requestId.value = currentRequestId;
  abortController.value = new AbortController();
  isLoading.value = true;
  hasError.value = false;

  try {
    const response = await KanbanBoardsAPI.getContactCards(props.contactId, {
      signal: abortController.value.signal,
    });

    if (currentRequestId !== requestId.value) return;

    cards.value = normalizeCollection(response);
  } catch (error) {
    if (isAbortError(error) || currentRequestId !== requestId.value) return;

    hasError.value = true;
    cards.value = [];
  } finally {
    if (currentRequestId === requestId.value) {
      isLoading.value = false;
      abortController.value = null;
    }
  }
};

const openConversation = card => {
  if (!card.conversation_id) return;

  router.push({
    name: 'inbox_conversation',
    params: {
      accountId: route.params.accountId,
      conversation_id: card.conversation_id,
    },
  });
};

// Criada, a ficha abre no Pipeline, como na maquete; ao voltar, a lista já a
// mostra.
const abrirFichaCriada = ({ id, boardId }) => {
  loadCards();
  if (!id || !boardId) return;
  router.push({
    name: 'kanban_board_show',
    params: { accountId: route.params.accountId, boardId },
    query: { cardId: id },
  });
};

watch(() => props.contactId, loadCards);

onMounted(loadCards);

onBeforeUnmount(() => {
  abortCurrentRequest();
  requestId.value += 1;
});
</script>

<template>
  <div
    v-if="isLoading"
    class="flex items-center justify-center py-10 text-n-slate-11"
  >
    <Spinner />
  </div>
  <p
    v-else-if="hasError"
    class="px-6 py-10 text-sm leading-6 text-center text-n-ruby-11"
  >
    {{ t('CONTACTS_LAYOUT.SIDEBAR.KANBAN.ERROR') }}
  </p>
  <div v-else-if="hasCards" class="px-6 py-2">
    <div
      class="flex items-center justify-between gap-3 border-b border-n-weak pb-3 pt-2"
    >
      <span class="text-sm text-n-slate-11">
        {{ t('CONTACTS_LAYOUT.SIDEBAR.KANBAN.COUNT', { count: cards.length }) }}
      </span>
      <Button
        sm
        outline
        slate
        icon="i-lucide-plus"
        data-testid="contact-kanban-new"
        :label="t('CONTACTS_LAYOUT.SIDEBAR.KANBAN.NEW')"
        @click="abrirNovaOportunidade"
      />
    </div>
    <article
      v-for="card in cards"
      :key="card.id"
      class="border-b border-n-weak py-4 last:border-b-0"
      data-testid="contact-kanban-card"
    >
      <div class="flex items-start justify-between gap-3">
        <div class="min-w-0">
          <h3 class="truncate text-sm font-medium text-n-slate-12">
            {{ card.subject }}
          </h3>
          <p
            class="mt-1 flex flex-wrap items-center gap-1 text-xs text-n-slate-11"
          >
            <span>
              {{
                t('CONTACTS_LAYOUT.SIDEBAR.KANBAN.WHERE', {
                  board: card.kanban_board?.name,
                  stage: card.kanban_stage?.name,
                })
              }}
            </span>
            <template v-if="formatAmount(card)">
              <i class="size-1 rounded-full bg-n-slate-8" aria-hidden="true" />
              <span data-testid="contact-kanban-amount">
                {{ formatAmount(card) }}
              </span>
            </template>
          </p>
        </div>
        <span
          v-if="card.kanban_stage?.color"
          class="mt-1 h-2 w-2 shrink-0 rounded-full bg-n-blue-9"
        />
      </div>

      <p
        v-if="card.expected_close_date"
        data-testid="contact-kanban-close-date"
        class="mt-3 text-xs text-n-slate-11"
      >
        {{
          t('CONTACTS_LAYOUT.SIDEBAR.KANBAN.EXPECTED_CLOSE', {
            date: formatCloseDate(card.expected_close_date),
          })
        }}
      </p>

      <div v-if="card.labels?.length" class="mt-3 flex flex-wrap gap-1">
        <span
          v-for="label in card.labels"
          :key="label.id || label.title"
          class="rounded-md bg-n-alpha-2 px-2 py-0.5 text-xs text-n-slate-11"
        >
          {{ label.title }}
        </span>
      </div>

      <Button
        v-if="card.conversation_id"
        link
        sm
        class="mt-3"
        data-testid="contact-kanban-open-conversation"
        :label="t('CONTACTS_LAYOUT.SIDEBAR.KANBAN.OPEN_CONVERSATION')"
        @click="openConversation(card)"
      />
    </article>
  </div>
  <div
    v-else
    data-testid="contact-kanban-empty"
    class="mx-6 my-6 flex flex-col items-center gap-2.5 rounded-xl border border-solid border-n-weak bg-n-alpha-1 px-4 py-5 text-center"
  >
    <i aria-hidden="true" class="i-lucide-kanban size-5 text-n-slate-11" />
    <p class="mb-0 text-sm text-n-slate-11">
      {{ t('CONTACTS_LAYOUT.SIDEBAR.KANBAN.EMPTY_STATE') }}
    </p>
    <Button
      sm
      data-testid="contact-kanban-new"
      :label="t('CONTACTS_LAYOUT.SIDEBAR.KANBAN.NEW')"
      @click="abrirNovaOportunidade"
    />
  </div>
  <KanbanContactOpportunityDialog
    ref="novaOportunidade"
    :contact-id="contactId"
    :contact-name="contactName"
    @created="abrirFichaCriada"
  />
</template>
