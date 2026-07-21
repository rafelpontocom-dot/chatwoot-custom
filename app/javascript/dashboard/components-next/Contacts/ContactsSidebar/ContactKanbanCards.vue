<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import KanbanBoardsAPI from 'dashboard/api/kanbanBoards';

import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  contactId: {
    type: [Number, String],
    required: true,
  },
});

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const cards = ref([]);
const isLoading = ref(false);
const hasError = ref(false);
const abortController = ref(null);
const requestId = ref(0);

const hasCards = computed(() => cards.value.length > 0);

const normalizeCollection = response =>
  response.data?.payload || response.data || [];

const isAbortError = error =>
  error?.name === 'AbortError' || error?.name === 'CanceledError';

const abortCurrentRequest = () => {
  abortController.value?.abort();
  abortController.value = null;
};

const formatDueAt = value => {
  if (!value) return t('CONTACTS_LAYOUT.SIDEBAR.KANBAN.NOT_SET');

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return String(value);

  return new Intl.DateTimeFormat(undefined, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(date);
};

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
          <p class="mt-1 flex flex-wrap gap-1 text-xs text-n-slate-11">
            <span>{{ card.kanban_board?.name }}</span>
            <span>{{ card.kanban_stage?.name }}</span>
          </p>
        </div>
        <span
          v-if="card.kanban_stage?.color"
          class="mt-1 h-2 w-2 shrink-0 rounded-full bg-n-blue-9"
        />
      </div>

      <p class="mt-3 flex flex-wrap gap-1 text-xs text-n-slate-11">
        <span>{{ t('CONTACTS_LAYOUT.SIDEBAR.KANBAN.DUE_DATE') }}</span>
        <span>{{ formatDueAt(card.due_at) }}</span>
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
  <p v-else class="px-6 py-10 text-sm leading-6 text-center text-n-slate-11">
    {{ t('CONTACTS_LAYOUT.SIDEBAR.KANBAN.EMPTY_STATE') }}
  </p>
</template>
