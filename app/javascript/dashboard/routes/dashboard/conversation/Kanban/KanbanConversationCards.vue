<script setup>
import {
  computed,
  nextTick,
  onBeforeUnmount,
  onMounted,
  ref,
  watch,
} from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import KanbanBoardsAPI from 'dashboard/api/kanbanBoards';
import { getKanbanStageColorClass } from 'dashboard/helper/kanbanStageColors';
import { requiredFieldOptions } from 'dashboard/helper/kanbanRequiredFields';
import LabelDropdown from 'shared/components/ui/label/LabelDropdown.vue';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
});

const { t } = useI18n();
const router = useRouter();
const store = useStore();
const currentChat = useMapGetter('getSelectedChat');
const accountLabels = useMapGetter('labels/getLabels');
const accountId = useMapGetter('getCurrentAccountId');

const cards = ref([]);
const isLoading = ref(false);
const hasError = ref(false);
const requestId = ref(0);
const abortController = ref(null);
const boardsAbortController = ref(null);
const stagesAbortController = ref(null);
const createAbortController = ref(null);
const boardsRequestId = ref(0);
const stagesRequestId = ref(0);

const isFormOpen = ref(false);
const boards = ref([]);
const stages = ref([]);
const selectedBoardId = ref('');
const selectedStageId = ref('');
const subject = ref('');
const nextActionType = ref('');
const nextActionAt = ref('');
const selectedLabelTitles = ref([]);
const isLoadingBoards = ref(false);
const isLoadingStages = ref(false);
const isCreating = ref(false);
const boardsError = ref('');
const stagesError = ref('');
const createError = ref('');
/**
 * Campos que a etapa de destino exige.
 *
 * Criar nesta etapa era impossível a partir da conversa: o servidor recusava com
 * «procedimento is required» e este painel não tinha onde preencher. O servidor
 * passa a dizer QUAIS faltam e COMO se desenham, e eles aparecem no formulário.
 */
const requiredFieldDefinitions = ref([]);
const requiredFieldValues = ref({});
const hasPendingRealtimeRefresh = ref(false);

const kanbanCardRealtimeEvents = new Set([
  'kanban.card.created',
  'kanban.card.updated',
  'kanban.card.deleted',
  'kanban.card.reordered',
]);

const hasCards = computed(() => cards.value.length > 0);
const activeBoards = computed(() =>
  boards.value.filter(board => board.active !== false)
);
const activeStages = computed(() =>
  stages.value.filter(stage => stage.active !== false)
);
const selectedBoard = computed(() =>
  activeBoards.value.find(
    board => Number(board.id) === Number(selectedBoardId.value)
  )
);
// O quadro decide os tipos de ação. Este payload não vem camelizado, ao
// contrário do da tela do funil, e ler só uma das formas dava lista vazia.
const nextActionTypeOptions = computed(() => {
  const board = selectedBoard.value || {};

  return board.nextActionTypes || board.next_action_types || [];
});

const selectedLabels = computed(() =>
  accountLabels.value.filter(label =>
    selectedLabelTitles.value.includes(label.title)
  )
);
const requiredFieldType = definition =>
  definition?.field_type || definition?.fieldType;

const isRequiredFieldSelect = definition =>
  ['select', 'boolean'].includes(requiredFieldType(definition));

const requiredFieldInputType = definition => {
  const tipo = requiredFieldType(definition);
  if (['integer', 'decimal', 'currency'].includes(tipo)) return 'number';
  if (tipo === 'date') return 'date';
  if (tipo === 'datetime') return 'datetime-local';

  return 'text';
};

const hasUnfilledRequiredField = computed(() =>
  requiredFieldDefinitions.value.some(definition => {
    const valor = requiredFieldValues.value[definition.key];

    return valor === undefined || valor === null || valor === '';
  })
);

const canSubmit = computed(
  () =>
    selectedBoardId.value &&
    selectedStageId.value &&
    !isCreating.value &&
    !hasUnfilledRequiredField.value
);

const contactId = computed(() => currentChat.value?.meta?.sender?.id);
const inboxId = computed(
  () => currentChat.value?.inbox_id || currentChat.value?.inboxId
);
const inbox = computed(() => {
  const getInboxById = store.getters?.['inboxes/getInboxById'];
  return getInboxById?.(inboxId.value) || {};
});
const defaultSubject = computed(() => {
  const contactName =
    currentChat.value?.meta?.sender?.name?.trim() ||
    `Contact #${contactId.value}`;
  const inboxName = inbox.value?.name?.trim() || `Inbox #${inboxId.value}`;

  return `${contactName} - ${inboxName}`;
});

const stageColorClass = getKanbanStageColorClass;

const openCardInBoard = card => {
  const boardId = card.kanban_board?.id || card.kanbanBoard?.id;
  if (!boardId || !card.id || !accountId.value) return;

  router.push({
    name: 'kanban_board_show',
    params: { accountId: accountId.value, boardId },
    query: { cardId: card.id },
  });
};

const normalizeCollection = response =>
  response.data?.payload || response.data || [];

const isAbortError = error =>
  error?.name === 'AbortError' || error?.name === 'CanceledError';

const getErrorMessage = (error, fallback) =>
  error?.response?.data?.error ||
  error?.response?.data?.message ||
  error?.message ||
  fallback;

const resetAbortController = () => {
  abortController.value?.abort();
  abortController.value = null;
};

const abortFormRequests = () => {
  boardsAbortController.value?.abort();
  stagesAbortController.value?.abort();
  createAbortController.value?.abort();
  boardsAbortController.value = null;
  stagesAbortController.value = null;
  createAbortController.value = null;
  boardsRequestId.value += 1;
  stagesRequestId.value += 1;
};

const resetFormState = () => {
  abortFormRequests();
  isFormOpen.value = false;
  boards.value = [];
  stages.value = [];
  selectedBoardId.value = '';
  selectedStageId.value = '';
  subject.value = '';
  nextActionType.value = '';
  nextActionAt.value = '';
  selectedLabelTitles.value = [];
  isLoadingBoards.value = false;
  isLoadingStages.value = false;
  isCreating.value = false;
  boardsError.value = '';
  stagesError.value = '';
  createError.value = '';
  requiredFieldDefinitions.value = [];
  requiredFieldValues.value = {};
};

const conversationIdFromRealtimeData = data =>
  data?.conversation_id ?? data?.conversationId ?? data?.card?.conversation_id;

const isCurrentConversationRealtimeData = data => {
  const eventConversationId = conversationIdFromRealtimeData(data);
  if (!eventConversationId) return true;

  return String(eventConversationId) === String(props.conversationId);
};

const shouldRefreshForRealtimeEvent = ({ event, data } = {}) => {
  if (!kanbanCardRealtimeEvents.has(event)) return false;

  return isCurrentConversationRealtimeData(data);
};

const loadCards = async () => {
  if (!props.conversationId) return;

  const currentRequestId = requestId.value + 1;
  requestId.value = currentRequestId;
  resetAbortController();

  const controller = new AbortController();
  abortController.value = controller;
  isLoading.value = true;
  hasError.value = false;

  try {
    const response = await KanbanBoardsAPI.getConversationCards(
      props.conversationId,
      { signal: controller.signal }
    );

    if (requestId.value !== currentRequestId || controller.signal.aborted) {
      return;
    }

    cards.value = response.data?.payload || [];
  } catch (error) {
    if (isAbortError(error) || requestId.value !== currentRequestId) {
      return;
    }

    cards.value = [];
    hasError.value = true;
  } finally {
    if (requestId.value === currentRequestId) {
      isLoading.value = false;
      abortController.value = null;

      if (hasPendingRealtimeRefresh.value && !isFormOpen.value) {
        hasPendingRealtimeRefresh.value = false;
        loadCards();
      }
    }
  }
};

const refreshCardsFromRealtime = () => {
  if (isFormOpen.value || isLoading.value) {
    hasPendingRealtimeRefresh.value = true;
    return;
  }

  loadCards();
};

const flushPendingRealtimeRefresh = () => {
  if (!hasPendingRealtimeRefresh.value || isFormOpen.value) return;

  hasPendingRealtimeRefresh.value = false;
  loadCards();
};

const loadStages = async boardId => {
  if (!boardId) return;

  const currentRequestId = stagesRequestId.value + 1;
  stagesRequestId.value = currentRequestId;
  stagesAbortController.value?.abort();

  const controller = new AbortController();
  stagesAbortController.value = controller;
  isLoadingStages.value = true;
  stagesError.value = '';
  stages.value = [];
  selectedStageId.value = '';

  try {
    const response = await KanbanBoardsAPI.showBoard(boardId, {
      signal: controller.signal,
    });

    if (
      stagesRequestId.value !== currentRequestId ||
      controller.signal.aborted
    ) {
      return;
    }

    stages.value = response.data?.stages || [];
    selectedStageId.value = activeStages.value[0]?.id || '';
  } catch (error) {
    if (isAbortError(error) || stagesRequestId.value !== currentRequestId) {
      return;
    }

    stagesError.value = getErrorMessage(
      error,
      t('CONVERSATION_SIDEBAR.KANBAN.ERROR')
    );
  } finally {
    if (stagesRequestId.value === currentRequestId) {
      isLoadingStages.value = false;
      stagesAbortController.value = null;
    }
  }
};

const loadBoards = async () => {
  const currentRequestId = boardsRequestId.value + 1;
  boardsRequestId.value = currentRequestId;
  boardsAbortController.value?.abort();

  const controller = new AbortController();
  boardsAbortController.value = controller;
  isLoadingBoards.value = true;
  boardsError.value = '';
  boards.value = [];
  selectedBoardId.value = '';
  stages.value = [];
  selectedStageId.value = '';

  try {
    const response = await KanbanBoardsAPI.getBoards({
      signal: controller.signal,
    });

    if (
      boardsRequestId.value !== currentRequestId ||
      controller.signal.aborted
    ) {
      return;
    }

    boards.value = normalizeCollection(response);
    selectedBoardId.value = activeBoards.value[0]?.id || '';

    if (selectedBoardId.value) {
      await loadStages(selectedBoardId.value);
    }
  } catch (error) {
    if (isAbortError(error) || boardsRequestId.value !== currentRequestId) {
      return;
    }

    boardsError.value = getErrorMessage(
      error,
      t('CONVERSATION_SIDEBAR.KANBAN.ERROR')
    );
  } finally {
    if (boardsRequestId.value === currentRequestId) {
      isLoadingBoards.value = false;
      boardsAbortController.value = null;
    }
  }
};

const openForm = () => {
  isFormOpen.value = true;
  subject.value = defaultSubject.value;
  nextActionType.value = '';
  nextActionAt.value = '';
  selectedLabelTitles.value = [];
  createError.value = '';
  store.dispatch('labels/get');
  loadBoards();
};

const cancelForm = () => {
  resetFormState();
  flushPendingRealtimeRefresh();
};

const onBoardChange = () => {
  selectedStageId.value = '';
  loadStages(selectedBoardId.value);
};

const onAddLabel = label => {
  const title = label?.title || label;
  if (!title || selectedLabelTitles.value.includes(title)) return;

  selectedLabelTitles.value = [...selectedLabelTitles.value, title];
};

const onRemoveLabel = title => {
  selectedLabelTitles.value = selectedLabelTitles.value.filter(
    labelTitle => labelTitle !== title
  );
};

const nextActionAtPayload = () => {
  if (!nextActionAt.value) return null;

  return new Date(nextActionAt.value).toISOString();
};

const submitForm = async () => {
  if (!canSubmit.value) return;

  createAbortController.value?.abort();
  const controller = new AbortController();
  createAbortController.value = controller;
  isCreating.value = true;
  createError.value = '';

  const card = {
    kanban_board_id: selectedBoardId.value,
    kanban_stage_id: selectedStageId.value,
    subject: subject.value.trim(),
    next_action_type: nextActionType.value || null,
    next_action_at: nextActionAtPayload(),
    labels: selectedLabelTitles.value,
  };
  if (requiredFieldDefinitions.value.length) {
    card.custom_field_values = { ...requiredFieldValues.value };
  }

  try {
    await KanbanBoardsAPI.createConversationCard(
      props.conversationId,
      { card },
      { signal: controller.signal }
    );

    if (controller.signal.aborted) return;

    useAlert(t('CONVERSATION_SIDEBAR.KANBAN.CREATED'));
    resetFormState();
    hasPendingRealtimeRefresh.value = false;
    await loadCards();
  } catch (error) {
    if (isAbortError(error)) return;

    const responseData = error?.response?.data;
    if (responseData?.missing_fields?.length) {
      requiredFieldDefinitions.value = responseData.field_definitions || [];
      requiredFieldValues.value = Object.fromEntries(
        responseData.missing_fields.map(key => [key, ''])
      );
      createError.value = t(
        'CONVERSATION_SIDEBAR.KANBAN.REQUIRED_FIELDS_PENDING'
      );
      // Os campos aparecem DEPOIS do clique; sem isto o foco ficava no <body>.
      await nextTick();
      document
        .querySelector(
          `[data-testid="kanban-create-field-${responseData.missing_fields[0]}"]`
        )
        ?.focus();
    } else {
      createError.value = getErrorMessage(
        error,
        t('CONVERSATION_SIDEBAR.KANBAN.CREATE_ERROR')
      );
    }
  } finally {
    if (createAbortController.value === controller) {
      isCreating.value = false;
      createAbortController.value = null;
    }
  }
};

const handleRealtimeKanbanEvent = eventPayload => {
  if (!shouldRefreshForRealtimeEvent(eventPayload)) return;

  refreshCardsFromRealtime();
};

onMounted(() => {
  emitter.on(BUS_EVENTS.KANBAN_REALTIME_EVENT, handleRealtimeKanbanEvent);
  loadCards();
});

watch(
  () => props.conversationId,
  () => {
    hasPendingRealtimeRefresh.value = false;
    resetFormState();
    loadCards();
  }
);

onBeforeUnmount(() => {
  resetAbortController();
  abortFormRequests();
  emitter.off(BUS_EVENTS.KANBAN_REALTIME_EVENT, handleRealtimeKanbanEvent);
});
</script>

<template>
  <div class="p-3 text-sm">
    <button
      v-if="!isFormOpen"
      type="button"
      class="mb-3 inline-flex h-8 items-center rounded-lg border border-solid border-n-strong px-3 text-sm font-medium text-n-slate-12 hover:bg-n-alpha-2"
      @click="openForm"
    >
      {{ t('CONVERSATION_SIDEBAR.KANBAN.ADD') }}
    </button>

    <form
      v-if="isFormOpen"
      class="mb-3 flex flex-col gap-3 rounded-lg border border-n-weak bg-n-surface-1 p-3"
      @submit.prevent="submitForm"
    >
      <h4 class="m-0 text-sm font-medium text-n-slate-12">
        {{ t('CONVERSATION_SIDEBAR.KANBAN.CREATE_TITLE') }}
      </h4>

      <label class="flex flex-col gap-1">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('CONVERSATION_SIDEBAR.KANBAN.BOARD') }}
        </span>
        <select
          v-model="selectedBoardId"
          class="h-9 rounded-md border border-n-strong bg-n-alpha-1 px-2 text-sm text-n-slate-12"
          :disabled="isLoadingBoards || activeBoards.length === 0"
          @change="onBoardChange"
        >
          <option value="">
            {{ t('CONVERSATION_SIDEBAR.KANBAN.SELECT_BOARD') }}
          </option>
          <option
            v-for="board in activeBoards"
            :key="board.id"
            :value="board.id"
          >
            {{ board.name }}
          </option>
        </select>
      </label>
      <p v-if="isLoadingBoards" class="m-0 text-xs text-n-slate-11">
        {{ t('CONVERSATION_SIDEBAR.KANBAN.LOADING') }}
      </p>
      <p v-else-if="boardsError" class="m-0 text-xs text-n-ruby-11">
        {{ boardsError }}
      </p>
      <p
        v-else-if="!isLoadingBoards && activeBoards.length === 0"
        class="m-0 text-xs text-n-slate-11"
      >
        {{ t('CONVERSATION_SIDEBAR.KANBAN.EMPTY_BOARDS') }}
      </p>

      <label class="flex flex-col gap-1">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('CONVERSATION_SIDEBAR.KANBAN.SUBJECT') }}
        </span>
        <input
          v-model="subject"
          type="text"
          class="h-9 rounded-md border border-n-strong bg-n-alpha-1 px-2 text-sm text-n-slate-12"
        />
      </label>

      <label class="flex flex-col gap-1">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('CONVERSATION_SIDEBAR.KANBAN.STAGE') }}
        </span>
        <select
          v-model="selectedStageId"
          class="h-9 rounded-md border border-n-strong bg-n-alpha-1 px-2 text-sm text-n-slate-12"
          :disabled="isLoadingStages || activeStages.length === 0"
        >
          <option value="">
            {{ t('CONVERSATION_SIDEBAR.KANBAN.SELECT_STAGE') }}
          </option>
          <option
            v-for="stage in activeStages"
            :key="stage.id"
            :value="stage.id"
          >
            {{ stage.name }}
          </option>
        </select>
      </label>
      <p v-if="isLoadingStages" class="m-0 text-xs text-n-slate-11">
        {{ t('CONVERSATION_SIDEBAR.KANBAN.LOADING') }}
      </p>
      <p v-else-if="stagesError" class="m-0 text-xs text-n-ruby-11">
        {{ stagesError }}
      </p>
      <p
        v-else-if="
          selectedBoard && !isLoadingStages && activeStages.length === 0
        "
        class="m-0 text-xs text-n-slate-11"
      >
        {{ t('CONVERSATION_SIDEBAR.KANBAN.EMPTY_STAGES') }}
      </p>

      <label class="flex flex-col gap-1">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('CONVERSATION_SIDEBAR.KANBAN.NEXT_ACTION_TYPE') }}
        </span>
        <select
          v-model="nextActionType"
          data-testid="kanban-conversation-next-action-type"
          class="h-9 rounded-md border border-n-strong bg-n-alpha-1 px-2 text-sm text-n-slate-12"
        >
          <option value="">
            {{ t('CONVERSATION_SIDEBAR.KANBAN.NOT_SET') }}
          </option>
          <option
            v-for="type in nextActionTypeOptions"
            :key="type"
            :value="type"
          >
            {{ type }}
          </option>
        </select>
      </label>

      <label class="flex flex-col gap-1">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('CONVERSATION_SIDEBAR.KANBAN.NEXT_ACTION_AT') }}
        </span>
        <input
          v-model="nextActionAt"
          type="datetime-local"
          data-testid="kanban-conversation-next-action-at"
          class="h-9 rounded-md border border-n-strong bg-n-alpha-1 px-2 text-sm text-n-slate-12"
        />
      </label>

      <label class="flex flex-col gap-2">
        <span class="text-xs font-medium text-n-slate-11">
          {{ t('CONVERSATION_SIDEBAR.KANBAN.LABELS') }}
        </span>
        <div v-if="selectedLabels.length" class="flex flex-wrap gap-1">
          <span
            v-for="label in selectedLabels"
            :key="label.title"
            class="inline-flex items-center gap-1 rounded-md bg-n-slate-3 px-2 py-1 text-xs text-n-slate-12"
          >
            {{ label.title }}
            <button
              type="button"
              class="text-n-slate-11 hover:text-n-slate-12"
              :aria-label="label.title"
              @click="onRemoveLabel(label.title)"
            >
              <span aria-hidden="true" class="i-lucide-x size-3" />
            </button>
          </span>
        </div>
        <div class="rounded-lg border border-n-weak bg-n-alpha-1 p-2">
          <LabelDropdown
            :account-labels="accountLabels"
            :selected-labels="selectedLabelTitles"
            :allow-creation="false"
            @add="onAddLabel"
            @remove="onRemoveLabel"
          />
        </div>
      </label>

      <!--
        Os campos que a etapa exige, preenchíveis aqui. O tipo vem do servidor:
        um `select` desenhado como texto livre deixa quem preenche a adivinhar as
        opções.
      -->
      <div
        v-if="requiredFieldDefinitions.length"
        data-testid="kanban-create-required-fields"
        class="flex flex-col gap-2 rounded-lg border border-n-weak bg-n-alpha-1 p-2"
      >
        <label
          v-for="definition in requiredFieldDefinitions"
          :key="definition.key"
          class="flex flex-col gap-1"
        >
          <span class="text-xs font-medium text-n-slate-11">
            {{ definition.label || definition.key }}
          </span>
          <select
            v-if="isRequiredFieldSelect(definition)"
            v-model="requiredFieldValues[definition.key]"
            :data-testid="`kanban-create-field-${definition.key}`"
            class="h-9 rounded-md border border-n-strong bg-n-alpha-1 px-2 text-sm text-n-slate-12"
          >
            <option value="" disabled>
              {{ t('CONVERSATION_SIDEBAR.KANBAN.SELECT_VALUE') }}
            </option>
            <option
              v-for="option in requiredFieldOptions(definition, t)"
              :key="String(option.value)"
              :value="option.value"
            >
              {{ option.label }}
            </option>
          </select>
          <input
            v-else
            v-model="requiredFieldValues[definition.key]"
            :data-testid="`kanban-create-field-${definition.key}`"
            :type="requiredFieldInputType(definition)"
            class="h-9 rounded-md border border-n-strong bg-n-alpha-1 px-2 text-sm text-n-slate-12"
          />
        </label>
      </div>

      <p v-if="createError" class="m-0 text-xs text-n-ruby-11" role="alert">
        {{ createError }}
      </p>

      <div class="flex justify-end gap-2">
        <button
          type="button"
          class="h-8 rounded-md px-3 text-sm text-n-slate-11 hover:bg-n-alpha-2"
          @click="cancelForm"
        >
          {{ t('CONVERSATION_SIDEBAR.KANBAN.CANCEL') }}
        </button>
        <button
          type="submit"
          class="h-8 rounded-md bg-n-brand px-3 text-sm font-medium text-white disabled:cursor-not-allowed disabled:opacity-60"
          :disabled="!canSubmit"
        >
          {{ t('CONVERSATION_SIDEBAR.KANBAN.CREATE') }}
        </button>
      </div>
    </form>

    <p v-if="isLoading" class="mb-0 text-n-slate-11">
      {{ t('CONVERSATION_SIDEBAR.KANBAN.LOADING') }}
    </p>
    <p v-else-if="hasError" class="mb-0 text-n-ruby-11">
      {{ t('CONVERSATION_SIDEBAR.KANBAN.ERROR') }}
    </p>
    <p v-else-if="!hasCards" class="mb-0 text-n-slate-11">
      {{ t('CONVERSATION_SIDEBAR.KANBAN.EMPTY') }}
    </p>
    <ul v-else class="m-0 flex list-none flex-col gap-2 p-0">
      <li v-for="card in cards" :key="card.id">
        <!--
          Na conversa a oportunidade não se edita: cria-se aqui e trabalha-se no
          funil. Decisão do Pedro, 07/10 — a ficha inteira (e depois o
          formulário em linha) tirava a conversa do lugar. Cada oportunidade é
          uma linha que leva ao cartão.
        -->
        <button
          type="button"
          data-testid="kanban-linked-card"
          class="flex w-full min-w-0 items-start justify-between gap-2 rounded-lg border border-solid border-n-weak bg-n-surface-1 p-3 text-start outline-none hover:bg-n-alpha-2 focus-visible:ring-2 focus-visible:ring-n-brand"
          :aria-label="
            t('CONVERSATION_SIDEBAR.KANBAN.OPEN_CARD_IN_BOARD', {
              subject: card.subject,
            })
          "
          @click="openCardInBoard(card)"
        >
          <span class="grid min-w-0 gap-1">
            <span class="break-words text-sm font-medium text-n-slate-12">
              {{ card.subject }}
            </span>
            <span
              class="flex min-w-0 flex-wrap items-center gap-x-1.5 text-xs text-n-slate-11"
            >
              {{ card.kanban_board?.name }}
              <span
                aria-hidden="true"
                class="i-lucide-arrow-right size-3 shrink-0"
              />
              <span
                v-if="card.kanban_stage?.color"
                class="size-2 flex-shrink-0 rounded-full"
                :class="stageColorClass(card.kanban_stage.color)"
                aria-hidden="true"
              />
              {{ card.kanban_stage?.name }}
            </span>
          </span>
          <span
            aria-hidden="true"
            class="i-lucide-arrow-up-right mt-0.5 size-4 shrink-0 text-n-slate-11"
          />
        </button>
      </li>
    </ul>
  </div>
</template>
