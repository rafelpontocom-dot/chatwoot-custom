<script setup>
import { computed, nextTick, onMounted, onUnmounted, ref, watch } from 'vue';
import { OnClickOutside } from '@vueuse/components';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import camelcaseKeys from 'camelcase-keys';
import Draggable from 'vuedraggable';

import { useAlert } from 'dashboard/composables';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import KanbanBoardsAPI from 'dashboard/api/kanbanBoards';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';
import { frontendURL, conversationUrl } from 'dashboard/helper/URLHelper';
import {
  DEFAULT_KANBAN_STAGE_COLOR,
  KANBAN_STAGE_COLOR_OPTIONS,
  getKanbanStageColorOption,
} from 'dashboard/helper/kanbanStageColors';
import { getKanbanStageIconOption } from 'dashboard/helper/kanbanStageIcons';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { REPLY_EDITOR_MODES } from 'dashboard/components/widgets/WootWriter/constants';
import KanbanConversationCard from './KanbanConversationCard.vue';
import KanbanActivityCenter from './KanbanActivityCenter.vue';
import KanbanOpportunityDetailsModal from './KanbanOpportunityDetailsModal.vue';
import KanbanOpportunityPicker from './KanbanOpportunityPicker.vue';
import KanbanListView from './KanbanListView.vue';
import KanbanConversationDrawer from './KanbanConversationDrawer.vue';

const route = useRoute();
const router = useRouter();
const { t } = useI18n();
const store = useStore();

const agents = useMapGetter('agents/getAgents');
const boards = useMapGetter('kanbanBoards/kanbanBoards');
const inboxes = useMapGetter('inboxes/getAllInboxes');
const isFetchingBoards = useMapGetter('kanbanBoards/kanbanBoardsLoading');
const { isAdmin } = useAdmin();
const selectedBoard = ref(null);
const isFetchingBoard = ref(false);
const isCreatingStage = ref(false);
const selectedOpportunityCardId = ref(null);
const opportunityTriggerElement = ref(null);
const opportunityDetailsModal = ref(null);
const activityTriggerElement = ref(null);
const viewMode = ref('kanban');
const showActivityCenter = ref(false);
const showFiltersPanel = ref(false);
const showSalesSummary = ref(false);
const showBoardActionsMenu = ref(false);
const showQuickCreate = ref(false);
const activeConversationCard = ref(null);
const activeActionKey = ref('');
const hasError = ref(false);
const selectedInboxIds = ref([]);
const selectedAssigneeIds = ref([]);
const selectedNextActionFilter = ref('');
const selectedStatusFilter = ref('');
const searchInput = ref('');
const selectedSearch = ref('');
const selectedSort = ref('');
const savedFilters = ref([]);
const selectedSavedFilterId = ref('');
const showSaveFilterForm = ref(false);
const savedFilterName = ref('');
const showRenameSavedFilterForm = ref(false);
const savedFilterRename = ref('');
const showDeleteSavedFilterConfirmation = ref(false);
const archivedCards = ref([]);
const showArchivedCards = ref(false);
const isLoadingArchivedCards = ref(false);
const restoringCardId = ref(null);
const selectedArchivedCardIds = ref([]);
const showBulkRestoreConfirmation = ref(false);
const selectedCardIds = ref([]);
const showBulkArchiveConfirmation = ref(false);
const showBulkImpactConfirmation = ref(false);
const pendingBulkOperation = ref(null);
const bulkLostReason = ref('');
const isBulkUpdating = ref(false);
const bulkOperationResult = ref(null);
const isBoardDropdownOpen = ref(false);
const editingStageId = ref(null);
const stageNames = ref({});
const stageColors = ref({});
const stageNameInputs = new Map();
const activeAddItemStageId = ref(null);
const stageCardsLoading = ref({});
const stageCardsErrors = ref({});
const stageRefreshRequests = new Map();
const cardPendingRemoval = ref(null);
const stagePendingRemoval = ref(null);
const showRemoveCardConfirmation = ref(false);
const showRemoveStageConfirmation = ref(false);
const isCardDragging = ref(false);
const hasCardDragChanged = ref(false);
const suppressNextCardClick = ref(false);
const isPersistingCardDrag = ref(false);
const pendingAssistedMove = ref(null);
const assistedMoveValues = ref({});
const defaultStageColor = DEFAULT_KANBAN_STAGE_COLOR;
const newStageColor = ref(defaultStageColor);
const cardDragFilter =
  'button,a,input,textarea,select,[contenteditable="true"],.no-drag';
const stageCardsPageLimit = 20;
const boardRefreshEvents = new Set([
  'kanban.board.updated',
  'kanban.stage.created',
  'kanban.stage.updated',
  'kanban.stage.deleted',
  'kanban.stage.reordered',
]);

const stageColorOptions = KANBAN_STAGE_COLOR_OPTIONS;

const activeBoardId = computed(() => Number(route.params.boardId) || null);
const requestedOpportunityCardId = computed(() => {
  const cardId = Number(route.query?.cardId);
  return cardId > 0 ? cardId : null;
});
const stages = computed(() => selectedBoard.value?.stages || []);
const salesSummary = computed(() => selectedBoard.value?.salesSummary || null);
const hasBoards = computed(() => boards.value.length > 0);
const hasMultipleBoards = computed(() => boards.value.length > 1);
const isInitialLoading = computed(
  () => isFetchingBoards.value && !selectedBoard.value
);
const currentBoardName = computed(
  () => selectedBoard.value?.name || t('KANBAN.NO_BOARD_SELECTED')
);
const boardAllowedInboxIds = computed(
  () => selectedBoard.value?.allowedInboxIds || []
);
const inboxFilterOptions = computed(() => {
  const availableInboxes =
    selectedBoard.value?.inboxScopeMode === 'selected_inboxes'
      ? inboxes.value.filter(inbox =>
          boardAllowedInboxIds.value.includes(inbox.id)
        )
      : inboxes.value;

  return availableInboxes.map(inbox => ({
    value: inbox.id,
    label: inbox.name,
  }));
});
const hasInboxFilterOptions = computed(
  () => inboxFilterOptions.value.length > 0
);
const agentFilterOptions = computed(() =>
  agents.value.map(agent => ({
    value: agent.id,
    label: agent.name || agent.email,
  }))
);
const hasAgentFilterOptions = computed(
  () => agentFilterOptions.value.length > 0
);
const nextActionFilterOptions = computed(() => [
  { value: '', label: t('KANBAN.FILTERS.ALL_ACTIONS') },
  { value: 'missing', label: t('KANBAN.FILTERS.MISSING_NEXT_ACTION') },
  { value: 'overdue', label: t('KANBAN.FILTERS.OVERDUE') },
  { value: 'due_today', label: t('KANBAN.FILTERS.DUE_TODAY') },
]);
const statusFilterOptions = computed(() => [
  { value: '', label: t('KANBAN.FILTERS.ALL_STATUSES') },
  { value: 'open', label: t('KANBAN.FILTERS.OPEN') },
  { value: 'won', label: t('KANBAN.FILTERS.WON') },
  { value: 'lost', label: t('KANBAN.FILTERS.LOST') },
]);
const sortOptions = computed(() => [
  { value: '', label: t('KANBAN.FILTERS.DEFAULT_ORDER') },
  { value: 'next_action_asc', label: t('KANBAN.FILTERS.NEXT_ACTION_FIRST') },
  { value: 'created_desc', label: t('KANBAN.FILTERS.NEWEST_FIRST') },
  { value: 'amount_desc', label: t('KANBAN.FILTERS.HIGHEST_VALUE') },
  { value: 'stage_time_desc', label: t('KANBAN.FILTERS.LONGEST_IN_STAGE') },
]);
const hasActiveFilters = computed(
  () =>
    selectedInboxIds.value.length > 0 ||
    selectedAssigneeIds.value.length > 0 ||
    selectedNextActionFilter.value ||
    selectedStatusFilter.value ||
    selectedSearch.value ||
    selectedSort.value
);
const openFilters = () => {
  showFiltersPanel.value = true;
};
const stageListModel = computed({
  get: () => selectedBoard.value?.stages || [],
  set: nextStages => {
    if (!selectedBoard.value) return;

    selectedBoard.value = { ...selectedBoard.value, stages: nextStages };
  },
});
const isCardDragDisabled = computed(
  () => isPersistingCardDrag.value || !!activeActionKey.value
);
const normalizePayload = data => camelcaseKeys(data || {}, { deep: true });
const formatCurrencyFromCents = amountCents =>
  new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  }).format(Number(amountCents || 0) / 100);
const stageCardCount = stage => stage.cardsCount ?? stage.cards?.length ?? 0;
const stageOverCapacity = stage =>
  Number(stage.wipLimit) > 0 && stageCardCount(stage) > Number(stage.wipLimit);
const selectedCardsCount = computed(() => selectedCardIds.value.length);
const pendingBulkImpactTarget = computed(() => {
  const pending = pendingBulkOperation.value;
  if (!pending) return '';

  if (pending.operation === 'move_stage') {
    return t('KANBAN.BULK.TARGET_STAGE', {
      target:
        stages.value.find(stage => stage.id === pending.attributes.stage_id)
          ?.name || t('KANBAN.CARD.UNKNOWN_STAGE'),
    });
  }

  if (pending.operation === 'assign_owner') {
    return t('KANBAN.BULK.TARGET_OWNER', {
      target:
        agentFilterOptions.value.find(
          option => option.value === pending.attributes.owner_id
        )?.label || t('KANBAN.CARD.UNASSIGNED'),
    });
  }

  if (pending.operation === 'mark_lost') {
    return t('KANBAN.BULK.TARGET_LOST_REASON', {
      target: pending.attributes.lost_reason,
    });
  }

  return t('KANBAN.BULK.NO_ADDITIONAL_DETAIL');
});
const pendingBulkImpactMessage = computed(() => {
  const pending = pendingBulkOperation.value;
  if (!pending)
    return t('KANBAN.BULK.IMPACT', { count: selectedCardsCount.value });

  return t('KANBAN.BULK.IMPACT_DETAILS', {
    count: selectedCardsCount.value,
    operation: pending.label,
    target: pendingBulkImpactTarget.value,
  });
});
const firstStageId = computed(() => stages.value[0]?.id || null);

const normalizeKanbanPayload = data => {
  const payload = normalizePayload(data);

  if (data?.pagination) {
    payload.pagination = {
      ...payload.pagination,
      nextCursor: data.pagination.next_cursor,
    };
  }

  if (data?.stages) {
    payload.stages = payload.stages.map((stage, index) => ({
      ...stage,
      pagination: data.stages[index]?.pagination
        ? {
            ...stage.pagination,
            nextCursor: data.stages[index].pagination.next_cursor,
          }
        : stage.pagination,
    }));
  }

  return payload;
};

const currentInboxFilterParams = () =>
  selectedInboxIds.value.length > 0
    ? { inbox_ids: selectedInboxIds.value }
    : {};
const currentAssigneeFilterParams = () =>
  selectedAssigneeIds.value.length > 0
    ? { assignee_ids: selectedAssigneeIds.value }
    : {};
const currentNextActionFilterParams = () =>
  selectedNextActionFilter.value
    ? { next_action: selectedNextActionFilter.value }
    : {};
const currentStatusFilterParams = () =>
  selectedStatusFilter.value ? { status: selectedStatusFilter.value } : {};
const currentSearchParams = () =>
  selectedSearch.value ? { search: selectedSearch.value } : {};
const currentSortParams = () =>
  selectedSort.value ? { sort: selectedSort.value } : {};
const currentFilterParams = () => ({
  ...currentInboxFilterParams(),
  ...currentAssigneeFilterParams(),
  ...currentNextActionFilterParams(),
  ...currentStatusFilterParams(),
  ...currentSearchParams(),
  ...currentSortParams(),
});
const currentBoardRequestConfig = () =>
  Object.keys(currentFilterParams()).length > 0
    ? { params: currentFilterParams() }
    : undefined;

const getErrorMessage = (error, fallbackMessage) =>
  error?.response?.data?.error ||
  error?.response?.data?.message ||
  error?.message ||
  fallbackMessage;

const isNameTakenError = error => {
  const errorMessage = String(getErrorMessage(error, '')).toLowerCase();
  return errorMessage.includes('name') && errorMessage.includes('taken');
};

const showActionError = (error, fallbackMessage) => {
  const message = isNameTakenError(error)
    ? t('KANBAN.ACTIONS.STAGE_NAME_TAKEN')
    : getErrorMessage(error, fallbackMessage);
  useAlert(message);
  return message;
};

const isRefreshRequiredError = error =>
  error?.response?.status === 409 &&
  error?.response?.data?.error === 'refresh_required';

const getStageCardsError = stageId => stageCardsErrors.value[stageId] || '';

const isStageCardsLoading = stageId => !!stageCardsLoading.value[stageId];

const setStageCardsLoading = (stageId, isLoading) => {
  stageCardsLoading.value = {
    ...stageCardsLoading.value,
    [stageId]: isLoading,
  };
};

const setStageCardsError = (stageId, message = '') => {
  stageCardsErrors.value = {
    ...stageCardsErrors.value,
    [stageId]: message,
  };
};

const mergeCardsById = (existingCards = [], nextCards = []) => {
  const cardIds = new Set(existingCards.map(card => card.id));
  const uniqueNextCards = nextCards.filter(card => {
    if (cardIds.has(card.id)) return false;

    cardIds.add(card.id);
    return true;
  });

  return [...existingCards, ...uniqueNextCards];
};

const updateStageCards = (stageId, updater) => {
  if (!selectedBoard.value) return;

  selectedBoard.value = {
    ...selectedBoard.value,
    stages: selectedBoard.value.stages.map(stage =>
      stage.id === stageId ? updater(stage) : stage
    ),
  };
};

const applyStageCardsPage = (stageId, page, shouldAppend = true) => {
  updateStageCards(stageId, stage => ({
    ...stage,
    cards: shouldAppend
      ? mergeCardsById(stage.cards, page.cards)
      : page.cards || [],
    pagination: page.pagination || stage.pagination,
  }));
};

const applyStageFirstPage = (stageId, page) => {
  updateStageCards(stageId, stage => ({
    ...stage,
    cards: page.cards || [],
    pagination: page.pagination || stage.pagination,
    cardsCount: page.pagination?.totalCount ?? stage.cardsCount,
  }));
  setStageCardsError(stageId);
};

const fetchStageCardsPage = async (stageId, params) => {
  const response = await KanbanBoardsAPI.getStageCards(
    selectedBoard.value.id,
    stageId,
    {
      ...params,
      ...currentFilterParams(),
    }
  );

  return normalizeKanbanPayload(response.data);
};

const reloadStageCards = async stageId => {
  const page = await fetchStageCardsPage(stageId, {
    limit: stageCardsPageLimit,
  });
  applyStageFirstPage(stageId, page);
};

const refreshStageFirstPage = stageId => {
  if (!selectedBoard.value?.id || !stageId) return Promise.resolve();

  if (stageRefreshRequests.has(stageId)) {
    return stageRefreshRequests.get(stageId);
  }

  const request = reloadStageCards(stageId).finally(() => {
    stageRefreshRequests.delete(stageId);
  });

  stageRefreshRequests.set(stageId, request);
  return request;
};

const refreshStageFirstPages = stageIds => {
  const uniqueStageIds = [...new Set(stageIds.filter(Boolean))];
  return Promise.all(
    uniqueStageIds.map(stageId => refreshStageFirstPage(stageId))
  );
};

const findCardStageId = card => {
  if (card?.kanbanStageId) return card.kanbanStageId;

  return stages.value.find(stage =>
    stage.cards.some(item => item.id === card?.id)
  )?.id;
};

const patchVisibleCard = card => {
  const updatedCard = normalizePayload(card);
  if (!updatedCard?.id) return false;

  const stageId = findCardStageId(updatedCard);
  if (
    !stageId ||
    (updatedCard.kanbanStageId && updatedCard.kanbanStageId !== stageId)
  ) {
    return false;
  }

  updateStageCards(stageId, stage => ({
    ...stage,
    cards: stage.cards.map(existingCard =>
      existingCard.id === updatedCard.id
        ? { ...existingCard, ...updatedCard }
        : existingCard
    ),
  }));

  return true;
};

const loadMoreStageCards = async stage => {
  if (!selectedBoard.value?.id || !stage?.id || isStageCardsLoading(stage.id)) {
    return;
  }

  setStageCardsLoading(stage.id, true);
  setStageCardsError(stage.id);

  try {
    const page = await fetchStageCardsPage(stage.id, {
      limit: stageCardsPageLimit,
      cursor: stage.pagination?.nextCursor,
    });
    applyStageCardsPage(stage.id, page);
  } catch (error) {
    if (isRefreshRequiredError(error)) {
      await reloadStageCards(stage.id);
      return;
    }

    setStageCardsError(stage.id, t('KANBAN.ACTIONS.LOAD_CARDS_ERROR'));
  } finally {
    setStageCardsLoading(stage.id, false);
  }
};

const getStageColorOption = getKanbanStageColorOption;

const getStageHeaderClass = stage =>
  getStageColorOption(stage.color).headerClass;

const getStageColorLabel = colorOption => {
  const labels = {
    slate: t('KANBAN.COLORS.SLATE'),
    blue: t('KANBAN.COLORS.BLUE'),
    teal: t('KANBAN.COLORS.TEAL'),
    green: t('KANBAN.COLORS.GREEN'),
    amber: t('KANBAN.COLORS.AMBER'),
    orange: t('KANBAN.COLORS.ORANGE'),
    ruby: t('KANBAN.COLORS.RUBY'),
    rose: t('KANBAN.COLORS.ROSE'),
    violet: t('KANBAN.COLORS.VIOLET'),
    iris: t('KANBAN.COLORS.IRIS'),
  };

  return labels[colorOption.value];
};

const getSelectStageColorLabel = colorOption =>
  t('KANBAN.ACTIONS.SELECT_STAGE_COLOR', {
    color: getStageColorLabel(colorOption),
  });

const showBoard = async boardId => {
  if (!boardId) {
    selectedBoard.value = null;
    return;
  }

  isFetchingBoard.value = true;
  hasError.value = false;

  try {
    const response = await KanbanBoardsAPI.showBoard(
      boardId,
      currentBoardRequestConfig()
    );
    stageCardsLoading.value = {};
    stageCardsErrors.value = {};
    selectedBoard.value = normalizeKanbanPayload(response.data);
    if (requestedOpportunityCardId.value) {
      selectedOpportunityCardId.value = requestedOpportunityCardId.value;
    }
    const savedFilterResponse = await KanbanBoardsAPI.getSavedFilters(boardId);
    savedFilters.value = savedFilterResponse.data || [];
  } catch {
    hasError.value = true;
    selectedBoard.value = null;
  } finally {
    isFetchingBoard.value = false;
  }
};

const refreshSelectedBoard = async () => {
  if (!selectedBoard.value?.id) return;

  await showBoard(selectedBoard.value.id);
};

const updateInboxFilter = async inboxIds => {
  selectedInboxIds.value = [...new Set(inboxIds)];
  await refreshSelectedBoard();
};

const updateAssigneeFilter = async assigneeIds => {
  selectedAssigneeIds.value = [...new Set(assigneeIds)];
  await refreshSelectedBoard();
};

const updateNextActionFilter = async value => {
  selectedNextActionFilter.value =
    selectedNextActionFilter.value === value ? '' : value;
  selectedSavedFilterId.value = '';
  await refreshSelectedBoard();
};

const updateStatusFilter = async value => {
  selectedStatusFilter.value =
    selectedStatusFilter.value === value ? '' : value;
  selectedSavedFilterId.value = '';
  await refreshSelectedBoard();
};

const applySearch = async () => {
  selectedSearch.value = searchInput.value.trim();
  selectedSavedFilterId.value = '';
  showSaveFilterForm.value = false;
  savedFilterName.value = '';
  await refreshSelectedBoard();
};

const clearSearch = async () => {
  if (!searchInput.value && !selectedSearch.value) return;

  searchInput.value = '';
  selectedSearch.value = '';
  selectedSavedFilterId.value = '';
  showSaveFilterForm.value = false;
  savedFilterName.value = '';
  await refreshSelectedBoard();
};

const updateSort = async event => {
  selectedSort.value = event.target.value;
  selectedSavedFilterId.value = '';
  await refreshSelectedBoard();
};

const clearFilters = async () => {
  selectedInboxIds.value = [];
  selectedAssigneeIds.value = [];
  selectedNextActionFilter.value = '';
  selectedStatusFilter.value = '';
  searchInput.value = '';
  selectedSearch.value = '';
  selectedSort.value = '';
  selectedSavedFilterId.value = '';
  await refreshSelectedBoard();
};

const exportFilteredCards = async () => {
  if (!selectedBoard.value?.id) return;

  try {
    const response = await KanbanBoardsAPI.exportCards(selectedBoard.value.id, {
      params: currentFilterParams(),
    });
    const blob = new Blob([response.data], { type: 'text/csv;charset=utf-8' });
    const downloadUrl = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = downloadUrl;
    link.download = `${currentBoardName.value.toLowerCase().replace(/\s+/g, '-')}-oportunidades.csv`;
    link.click();
    URL.revokeObjectURL(downloadUrl);
  } catch (error) {
    showActionError(error, t('KANBAN.REPORTS.EXPORT_ERROR'));
  }
};

const applySavedFilter = async event => {
  selectedSavedFilterId.value = event.target.value;
  const savedFilter = savedFilters.value.find(
    filter => String(filter.id) === selectedSavedFilterId.value
  );
  if (!savedFilter) return;

  const filters = savedFilter.filters || {};
  selectedInboxIds.value = filters.inbox_ids || [];
  selectedAssigneeIds.value = filters.assignee_ids || [];
  selectedNextActionFilter.value = filters.next_action || '';
  selectedStatusFilter.value = filters.status || '';
  searchInput.value = filters.search || '';
  selectedSearch.value = filters.search || '';
  selectedSort.value = filters.sort || '';
  savedFilterRename.value = savedFilter.name;
  await refreshSelectedBoard();
};

const selectedSavedFilter = computed(() =>
  savedFilters.value.find(
    filter => String(filter.id) === String(selectedSavedFilterId.value)
  )
);

const openRenameSavedFilter = () => {
  if (!selectedSavedFilter.value) return;

  savedFilterRename.value = selectedSavedFilter.value.name;
  showRenameSavedFilterForm.value = true;
  showFiltersPanel.value = true;
};

const renameSavedFilter = async () => {
  const filter = selectedSavedFilter.value;
  const name = savedFilterRename.value.trim();
  if (!filter || !name) return;

  try {
    const response = await KanbanBoardsAPI.updateSavedFilter(
      selectedBoard.value.id,
      filter.id,
      { saved_filter: { name, filters: filter.filters } }
    );
    savedFilters.value = savedFilters.value.map(item =>
      item.id === filter.id ? { ...item, ...(response.data || {}), name } : item
    );
    showRenameSavedFilterForm.value = false;
    useAlert(t('KANBAN.FILTERS.RENAMED_SUCCESS'));
  } catch (error) {
    showActionError(error, t('KANBAN.FILTERS.RENAME_ERROR'));
  }
};

const deleteSavedFilter = async () => {
  const filter = selectedSavedFilter.value;
  if (!filter) return;

  try {
    await KanbanBoardsAPI.deleteSavedFilter(selectedBoard.value.id, filter.id);
    savedFilters.value = savedFilters.value.filter(
      item => item.id !== filter.id
    );
    selectedSavedFilterId.value = '';
    showDeleteSavedFilterConfirmation.value = false;
    useAlert(t('KANBAN.FILTERS.DELETED_SUCCESS'));
  } catch (error) {
    showActionError(error, t('KANBAN.FILTERS.DELETE_ERROR'));
  }
};

const saveCurrentFilter = async () => {
  if (!hasActiveFilters.value) return;

  const name = savedFilterName.value.trim();
  if (!name) return;

  await KanbanBoardsAPI.createSavedFilter(selectedBoard.value.id, {
    saved_filter: { name, filters: currentFilterParams() },
  });
  const response = await KanbanBoardsAPI.getSavedFilters(
    selectedBoard.value.id
  );
  savedFilters.value = response.data || [];
  showSaveFilterForm.value = false;
  savedFilterName.value = '';
  useAlert(t('KANBAN.FILTERS.SAVED_SUCCESS'));
};

const toggleSaveFilterForm = () => {
  showSaveFilterForm.value = !showSaveFilterForm.value;
  if (showSaveFilterForm.value) showFiltersPanel.value = true;
  if (!showSaveFilterForm.value) savedFilterName.value = '';
};

const openArchivedCards = async () => {
  if (!selectedBoard.value?.id || isLoadingArchivedCards.value) return;

  showArchivedCards.value = true;
  isLoadingArchivedCards.value = true;
  try {
    const response = await KanbanBoardsAPI.getArchivedCards(
      selectedBoard.value.id
    );
    archivedCards.value = normalizeKanbanPayload(response.data || []);
  } catch (error) {
    showActionError(error, t('KANBAN.ARCHIVE.LOAD_ERROR'));
  } finally {
    isLoadingArchivedCards.value = false;
  }
};

const closeArchivedCards = () => {
  if (restoringCardId.value) return;
  showArchivedCards.value = false;
  selectedArchivedCardIds.value = [];
};

const restoreArchivedCard = async card => {
  if (!selectedBoard.value?.id || restoringCardId.value) return;

  restoringCardId.value = card.id;
  try {
    await KanbanBoardsAPI.restoreCardById(selectedBoard.value.id, card.id);
    archivedCards.value = archivedCards.value.filter(
      item => item.id !== card.id
    );
    await refreshSelectedBoard();
    useAlert(t('KANBAN.ARCHIVE.RESTORE_SUCCESS'));
  } catch (error) {
    showActionError(error, t('KANBAN.ARCHIVE.RESTORE_ERROR'));
  } finally {
    restoringCardId.value = null;
  }
};

const toggleArchivedCardSelection = (card, selected) => {
  selectedArchivedCardIds.value = selected
    ? [...new Set([...selectedArchivedCardIds.value, card.id])]
    : selectedArchivedCardIds.value.filter(cardId => cardId !== card.id);
};

const bulkRestoreArchivedCards = async () => {
  if (!selectedBoard.value?.id || !selectedArchivedCardIds.value.length) return;

  restoringCardId.value = 'bulk';
  try {
    const response = await KanbanBoardsAPI.bulkUpdateCards(
      selectedBoard.value.id,
      {
        card_ids: selectedArchivedCardIds.value,
        operation: 'restore',
      }
    );
    const restoredIds = new Set(
      selectedArchivedCardIds.value.slice(0, response.data?.updated_count || 0)
    );
    archivedCards.value = archivedCards.value.filter(
      card => !restoredIds.has(card.id)
    );
    selectedArchivedCardIds.value = [];
    showBulkRestoreConfirmation.value = false;
    await refreshSelectedBoard();
    useAlert(
      t('KANBAN.BULK.SUCCESS_WITH_COUNT', {
        count: response.data?.updated_count || 0,
        errors: response.data?.failed_count || 0,
      })
    );
  } catch (error) {
    showActionError(error, t('KANBAN.ARCHIVE.RESTORE_ERROR'));
  } finally {
    restoringCardId.value = null;
  }
};

const toggleCardSelection = (card, selected) => {
  selectedCardIds.value = selected
    ? [...new Set([...selectedCardIds.value, card.id])]
    : selectedCardIds.value.filter(cardId => cardId !== card.id);
};

const toggleVisibleCardSelection = (cardIds, selected) => {
  const ids = cardIds.map(Number);

  selectedCardIds.value = selected
    ? [...new Set([...selectedCardIds.value, ...ids])]
    : selectedCardIds.value.filter(cardId => !ids.includes(cardId));
};

const clearCardSelection = () => {
  selectedCardIds.value = [];
};

const performBulkOperation = async (operation, attributes = {}) => {
  if (
    !selectedBoard.value?.id ||
    !selectedCardsCount.value ||
    isBulkUpdating.value
  )
    return;

  isBulkUpdating.value = true;
  bulkOperationResult.value = null;
  const selectedCount = selectedCardsCount.value;
  try {
    const response = await KanbanBoardsAPI.bulkUpdateCards(
      selectedBoard.value.id,
      {
        card_ids: selectedCardIds.value,
        operation,
        ...attributes,
      }
    );
    clearCardSelection();
    showBulkArchiveConfirmation.value = false;
    showBulkImpactConfirmation.value = false;
    pendingBulkOperation.value = null;
    await refreshSelectedBoard();
    const message = t('KANBAN.BULK.SUCCESS_WITH_COUNT', {
      count: response.data?.updated_count ?? selectedCount,
      errors: response.data?.failed_count || 0,
    });
    bulkOperationResult.value = { type: 'success', message };
    useAlert(message);
  } catch (error) {
    bulkOperationResult.value = {
      type: 'error',
      message: showActionError(error, t('KANBAN.BULK.ERROR')),
    };
  } finally {
    isBulkUpdating.value = false;
  }
};

const updateBulkOwner = event => {
  const ownerId = Number(event.target.value);
  if (!ownerId) return;

  pendingBulkOperation.value = {
    operation: 'assign_owner',
    attributes: { owner_id: ownerId },
    label: t('KANBAN.BULK.ASSIGN'),
  };
  showBulkImpactConfirmation.value = true;
};

const updateBulkStage = event => {
  const stageId = Number(event.target.value);
  if (!stageId) return;

  pendingBulkOperation.value = {
    operation: 'move_stage',
    attributes: { stage_id: stageId },
    label: t('KANBAN.BULK.MOVE'),
  };
  showBulkImpactConfirmation.value = true;
};

const prepareBulkOperation = (operation, label, attributes = {}) => {
  pendingBulkOperation.value = { operation, attributes, label };
  showBulkImpactConfirmation.value = true;
};

const prepareBulkWon = () =>
  prepareBulkOperation('mark_won', t('KANBAN.BULK.MARK_WON'));

const prepareBulkLost = () => {
  if (!bulkLostReason.value) return;
  prepareBulkOperation('mark_lost', t('KANBAN.BULK.MARK_LOST'), {
    lost_reason: bulkLostReason.value,
  });
};

const confirmBulkImpact = async () => {
  if (!pendingBulkOperation.value) return;

  await performBulkOperation(
    pendingBulkOperation.value.operation,
    pendingBulkOperation.value.attributes
  );
};

const closeBulkImpactConfirmation = () => {
  if (isBulkUpdating.value) return;

  showBulkImpactConfirmation.value = false;
  pendingBulkOperation.value = null;
};

const openBoardSettings = () => {
  if (!selectedBoard.value?.id) return;

  router.push({
    name: 'kanban_board_settings',
    params: {
      accountId: route.params.accountId,
      boardId: selectedBoard.value.id,
    },
  });
};

const openBoardAutomations = () => {
  if (!selectedBoard.value?.id) return;

  router.push({
    name: 'kanban_board_automations',
    params: {
      accountId: route.params.accountId,
      boardId: selectedBoard.value.id,
    },
  });
};

const setStageNameInput = (stageId, element) => {
  if (element) {
    stageNameInputs.set(stageId, element);
    return;
  }

  stageNameInputs.delete(stageId);
};

const findCreatedStage = (createdStage, temporaryName) => {
  if (createdStage?.id) {
    return stages.value.find(stage => stage.id === createdStage.id);
  }

  return stages.value.find(stage => stage.name === temporaryName);
};

const getUniqueTemporaryStageName = () => {
  const baseName = t('KANBAN.ACTIONS.NEW_STAGE_NAME');
  const existingNames = new Set(stages.value.map(stage => stage.name));

  if (!existingNames.has(baseName)) return baseName;

  let suffix = 1;
  let nextName = `${baseName} (${suffix})`;

  while (existingNames.has(nextName)) {
    suffix += 1;
    nextName = `${baseName} (${suffix})`;
  }

  return nextName;
};

const startEditingStage = stage => {
  editingStageId.value = stage.id;
  stageNames.value = {
    ...stageNames.value,
    [stage.id]: stage.name,
  };
  stageColors.value = {
    ...stageColors.value,
    [stage.id]: getStageColorOption(stage.color).value,
  };
  nextTick(() => stageNameInputs.get(stage.id)?.focus());
};

const createStage = async () => {
  if (!selectedBoard.value?.id || isCreatingStage.value) return;

  const name = getUniqueTemporaryStageName();

  isCreatingStage.value = true;

  try {
    const response = await KanbanBoardsAPI.createStage(selectedBoard.value.id, {
      stage: {
        name,
        color: newStageColor.value,
        position: stages.value.length,
      },
    });
    newStageColor.value = defaultStageColor;
    const createdStage = normalizePayload(response.data);
    await refreshSelectedBoard();
    const stageToEdit = findCreatedStage(createdStage, name);
    if (stageToEdit) startEditingStage(stageToEdit);
    useAlert(t('KANBAN.ACTIONS.CREATE_STAGE_SUCCESS'));
  } catch (error) {
    showActionError(error, t('KANBAN.ACTIONS.CREATE_STAGE_ERROR'));
  } finally {
    isCreatingStage.value = false;
  }
};

const cancelEditingStage = () => {
  editingStageId.value = null;
};

const updateStage = async stage => {
  const name = String(stageNames.value[stage.id] || '').trim();
  const color = stageColors.value[stage.id] || defaultStageColor;
  if (!selectedBoard.value?.id || !name || activeActionKey.value) return;

  activeActionKey.value = `update-stage-${stage.id}`;

  try {
    await KanbanBoardsAPI.updateStage(selectedBoard.value.id, stage.id, {
      stage: {
        name,
        color,
      },
    });
    cancelEditingStage();
    await refreshSelectedBoard();
    useAlert(t('KANBAN.ACTIONS.UPDATE_STAGE_SUCCESS'));
  } catch (error) {
    showActionError(error, t('KANBAN.ACTIONS.UPDATE_STAGE_ERROR'));
  } finally {
    activeActionKey.value = '';
  }
};

const openRemoveStageConfirmation = stage => {
  if (stage.cards.length > 0) {
    showActionError(null, t('KANBAN.ACTIONS.REMOVE_STAGE_NOT_EMPTY'));
    return;
  }

  stagePendingRemoval.value = stage;
  showRemoveStageConfirmation.value = true;
};

const closeRemoveStageConfirmation = () => {
  showRemoveStageConfirmation.value = false;
  stagePendingRemoval.value = null;
};

const removeStage = async stage => {
  if (!selectedBoard.value?.id || !stage?.id || activeActionKey.value) return;

  activeActionKey.value = `remove-stage-${stage.id}`;

  try {
    await KanbanBoardsAPI.deleteStage(selectedBoard.value.id, stage.id);
    await refreshSelectedBoard();
    useAlert(t('KANBAN.ACTIONS.REMOVE_STAGE_SUCCESS'));
  } catch (error) {
    showActionError(error, t('KANBAN.ACTIONS.REMOVE_STAGE_ERROR'));
  } finally {
    activeActionKey.value = '';
  }
};

const confirmRemoveStage = async () => {
  const stage = stagePendingRemoval.value;
  closeRemoveStageConfirmation();

  if (!stage) return;

  await removeStage(stage);
};

const toggleAddItemPicker = stage => {
  if (activeAddItemStageId.value === stage.id) {
    activeAddItemStageId.value = null;
    return;
  }

  activeAddItemStageId.value = stage.id;
};

const closeAddItemPicker = () => {
  activeAddItemStageId.value = null;
};

const openQuickOpportunityPicker = () => {
  if (firstStageId.value) showQuickCreate.value = true;
};

const reorderStageByPosition = async (stage, position) => {
  if (!selectedBoard.value?.id || !stage?.id || activeActionKey.value) return;

  activeActionKey.value = `reorder-stage-${stage.id}`;

  try {
    await KanbanBoardsAPI.reorderStage(selectedBoard.value.id, stage.id, {
      position,
    });
    await refreshSelectedBoard();
  } catch (error) {
    showActionError(error, t('KANBAN.ACTIONS.REORDER_STAGE_ERROR'));
    await refreshSelectedBoard();
  } finally {
    activeActionKey.value = '';
  }
};

const onStageDragEnd = async event => {
  const stageId = Number(event?.item?.dataset?.stageId);
  const newIndex = event?.newIndex;
  const oldIndex = event?.oldIndex;
  if (!stageId || oldIndex === newIndex || newIndex === undefined) return;

  const stage = stages.value.find(item => item.id === stageId);
  if (!stage) return;

  await reorderStageByPosition(stage, newIndex + 1);
};

const openBookingStageOpportunity = (cardId, stageId, stageChanged) => {
  if (
    !stageChanged ||
    !selectedBoard.value?.calendarEnabled ||
    !selectedBoard.value.calendarBookingStageIds
      ?.map(Number)
      .includes(Number(stageId))
  ) {
    return;
  }

  selectedOpportunityCardId.value = cardId;
};

const onCardDragStart = () => {
  isCardDragging.value = true;
  hasCardDragChanged.value = false;
};

const onCardDragChange = async (stage, event) => {
  if (event?.added || event?.moved || event?.removed) {
    hasCardDragChanged.value = true;
  }

  const card = event?.added?.element || event?.moved?.element;
  const targetIndex = event?.added?.newIndex ?? event?.moved?.newIndex;
  if (
    !selectedBoard.value?.id ||
    !stage?.id ||
    !card ||
    targetIndex === undefined ||
    isPersistingCardDrag.value
  ) {
    return;
  }

  const destinationPosition = targetIndex + 1;
  const stageChanged = card.kanbanStageId !== stage.id;
  const positionChanged = card.position !== destinationPosition;
  if (!stageChanged && !positionChanged) return;

  isPersistingCardDrag.value = true;
  activeActionKey.value = `reorder-card-${card.id}`;
  const payload = {
    card: {
      kanban_stage_id: stage.id,
      position: destinationPosition,
    },
  };

  try {
    await KanbanBoardsAPI.reorderCardById(
      selectedBoard.value.id,
      card.id,
      payload
    );
    await refreshStageFirstPages([card.kanbanStageId, stage.id]);
    openBookingStageOpportunity(card.id, stage.id, stageChanged);
  } catch (error) {
    const responseData = error?.response?.data;
    if (responseData?.missing_fields?.length) {
      pendingAssistedMove.value = {
        boardId: selectedBoard.value.id,
        cardId: card.id,
        sourceStageId: card.kanbanStageId,
        targetStageId: stage.id,
        position: destinationPosition,
        missingFields: responseData.missing_fields,
        fieldDefinitions: responseData.field_definitions || [],
      };
      assistedMoveValues.value = {};
    } else {
      showActionError(error, t('KANBAN.ACTIONS.REORDER_CARD_ERROR'));
    }
    await refreshStageFirstPages([card.kanbanStageId, stage.id]);
  } finally {
    isPersistingCardDrag.value = false;
    activeActionKey.value = '';
  }
};

const closeAssistedMove = () => {
  pendingAssistedMove.value = null;
  assistedMoveValues.value = {};
};

const assistedFieldDefinition = fieldKey => {
  if (fieldKey === 'lost_reason') {
    return {
      key: fieldKey,
      label: t('KANBAN.OPPORTUNITY.LOST_REASON'),
      fieldType: 'select',
      options: selectedBoard.value?.lostReasonOptions || [],
    };
  }

  return pendingAssistedMove.value?.fieldDefinitions.find(
    definition => definition.key === fieldKey
  );
};

const assistedInputType = definition => {
  const fieldType = definition?.fieldType || definition?.field_type;
  if (['integer', 'decimal', 'currency'].includes(fieldType)) return 'number';
  if (fieldType === 'date') return 'date';
  if (fieldType === 'datetime') return 'datetime-local';
  return 'text';
};

const confirmAssistedMove = async () => {
  const move = pendingAssistedMove.value;
  if (!move || isPersistingCardDrag.value) return;

  const cardPayload = {
    kanban_stage_id: move.targetStageId,
    position: move.position,
  };
  const customFieldValues = { ...assistedMoveValues.value };
  if (move.missingFields.includes('lost_reason')) {
    cardPayload.lost_reason = customFieldValues.lost_reason;
    delete customFieldValues.lost_reason;
  }
  if (Object.keys(customFieldValues).length) {
    cardPayload.custom_field_values = customFieldValues;
  }

  isPersistingCardDrag.value = true;
  try {
    await KanbanBoardsAPI.reorderCardById(move.boardId, move.cardId, {
      card: cardPayload,
    });
    closeAssistedMove();
    await refreshStageFirstPages([move.sourceStageId, move.targetStageId]);
    openBookingStageOpportunity(move.cardId, move.targetStageId, true);
  } catch (error) {
    showActionError(error, t('KANBAN.ACTIONS.REORDER_CARD_ERROR'));
  } finally {
    isPersistingCardDrag.value = false;
  }
};

const onCardDragEnd = () => {
  if (isCardDragging.value || hasCardDragChanged.value) {
    suppressNextCardClick.value = true;
    window.setTimeout(() => {
      suppressNextCardClick.value = false;
    }, 0);
  }

  isCardDragging.value = false;
  hasCardDragChanged.value = false;
};

const moveCardToStage = (card, targetStageId) => {
  const targetStage = stages.value.find(stage => stage.id === targetStageId);
  if (!targetStage || card.kanbanStageId === targetStageId) return;

  onCardDragChange(targetStage, {
    added: {
      element: card,
      newIndex: stageCardCount(targetStage),
    },
  });
};

const openRemoveCardConfirmation = card => {
  cardPendingRemoval.value = card;
  showRemoveCardConfirmation.value = true;
};

const closeRemoveCardConfirmation = () => {
  showRemoveCardConfirmation.value = false;
  cardPendingRemoval.value = null;
};

const removeCard = async card => {
  if (!selectedBoard.value?.id || activeActionKey.value) return;

  activeActionKey.value = `remove-card-${card.id}`;

  try {
    await KanbanBoardsAPI.deleteCardById(selectedBoard.value.id, card.id);
    await refreshStageFirstPage(findCardStageId(card));
    useAlert(t('KANBAN.ACTIONS.REMOVE_CARD_SUCCESS'));
  } catch (error) {
    showActionError(error, t('KANBAN.ACTIONS.REMOVE_CARD_ERROR'));
  } finally {
    activeActionKey.value = '';
  }
};

const confirmRemoveCard = async () => {
  const card = cardPendingRemoval.value;
  closeRemoveCardConfirmation();

  if (!card) return;

  await removeCard(card);
};

const selectBoard = boardId => {
  if (boardId === activeBoardId.value) return;

  isBoardDropdownOpen.value = false;
  router.push({
    name: 'kanban_board_show',
    params: {
      accountId: route.params.accountId,
      boardId,
    },
  });
};

const fetchBoards = async () => {
  hasError.value = false;

  try {
    await Promise.all([
      store.dispatch('kanbanBoards/fetchBoards'),
      inboxes.value.length ? Promise.resolve() : store.dispatch('inboxes/get'),
      agents.value.length ? Promise.resolve() : store.dispatch('agents/get'),
    ]);

    const nextBoardId = activeBoardId.value || boards.value[0]?.id;
    if (nextBoardId && !activeBoardId.value) {
      router.replace({
        name: 'kanban_board_show',
        params: {
          accountId: route.params.accountId,
          boardId: nextBoardId,
        },
      });
      return;
    }

    if (nextBoardId) {
      await showBoard(nextBoardId);
    }
  } catch {
    hasError.value = true;
    selectedBoard.value = null;
  }
};

const getContactName = card =>
  card.contact?.name ||
  card.conversation?.meta?.sender?.name ||
  t('KANBAN.CARD.UNKNOWN_CONTACT');

const removeCardMessageValue = computed(() => {
  if (!cardPendingRemoval.value) return '';

  return getContactName(cardPendingRemoval.value);
});
const removeStageMessageValue = computed(
  () => stagePendingRemoval.value?.name || ''
);

const openConversation = (card, event = {}) => {
  if (!card?.conversationId) return;

  if (suppressNextCardClick.value) {
    suppressNextCardClick.value = false;
    return;
  }

  if (event.metaKey || event.ctrlKey) {
    const path = frontendURL(
      conversationUrl({
        accountId: route.params.accountId,
        id: card.conversationId,
      })
    );
    window.open(
      `${window.chatwootConfig.hostURL}${path}`,
      '_blank',
      'noopener noreferrer nofollow'
    );
    return;
  }

  activeConversationCard.value = card;
};

const closeConversationDrawer = () => {
  activeConversationCard.value = null;
};

const openFullConversation = () => {
  const card = activeConversationCard.value;
  if (!card?.conversationId) return;

  router.push({
    path: frontendURL(
      conversationUrl({
        accountId: route.params.accountId,
        id: card.conversationId,
      })
    ),
  });
};

const openDetails = card => {
  if (suppressNextCardClick.value) {
    suppressNextCardClick.value = false;
    return;
  }

  opportunityTriggerElement.value = document.activeElement;
  selectedOpportunityCardId.value = card.id;
};

const closeOpportunityDetails = () => {
  selectedOpportunityCardId.value = null;
  if (!requestedOpportunityCardId.value) return;

  const { cardId, ...query } = route.query;
  router.replace({
    name: 'kanban_board_show',
    params: {
      accountId: route.params.accountId,
      boardId: selectedBoard.value?.id || route.params.boardId,
    },
    query,
  });
};
const requestOpportunityClose = event => {
  if (opportunityDetailsModal.value?.requestClose) {
    opportunityDetailsModal.value.requestClose(event);
    return;
  }

  closeOpportunityDetails();
};

const openActivityCenter = event => {
  activityTriggerElement.value = event?.currentTarget || null;
  showActivityCenter.value = true;
};
const closeActivityCenter = ({ restoreFocus = true } = {}) => {
  showActivityCenter.value = false;
  if (!restoreFocus) return;

  nextTick(() => activityTriggerElement.value?.focus?.());
};

const handleOpportunityKeydown = event => {
  if (event.key === 'Escape' && selectedOpportunityCardId.value) {
    event.preventDefault();
    closeOpportunityDetails();
  }
};

const openFieldSettings = ({ action } = {}) => {
  if (!selectedBoard.value?.id) return;

  closeOpportunityDetails();
  router.push({
    name: 'kanban_board_settings',
    params: {
      accountId: route.params.accountId,
      boardId: selectedBoard.value.id,
    },
    query: {
      section: 'fields',
      ...(action === 'newTab' ? { action: 'new-tab' } : {}),
    },
  });
};

const onOpportunityUpdated = updatedCard => {
  if (patchVisibleCard(updatedCard)) return;

  refreshStageFirstPage(
    findCardStageId({
      id: selectedOpportunityCardId.value,
      kanbanStageId: updatedCard?.kanbanStageId,
    })
  );
};

const onOpportunityTransferred = async ({ boardId, card }) => {
  selectedOpportunityCardId.value = null;
  await router.push({
    name: 'kanban_board_show',
    params: { accountId: route.params.accountId, boardId },
    query: { cardId: card.id },
  });
};

const onOpportunityOpenConversation = card => {
  openConversation(card, {});
};

const onOpportunitySendPaymentLink = ({ card, payment }) => {
  if (!card?.conversationId || !payment?.invoice_url) return;

  const key = `draft-${card.conversationId}-${REPLY_EDITOR_MODES.REPLY}`;
  const currentDraft = store.getters['draftMessages/get'](key);
  const message = [currentDraft, payment.invoice_url]
    .filter(Boolean)
    .join('\n');

  store.dispatch('draftMessages/set', { key, message });
  openConversation(card, {});
};

const onOpportunitySendFormLink = ({ card, url }) => {
  if (!card?.conversationId || !url) return;

  const key = `draft-${card.conversationId}-${REPLY_EDITOR_MODES.REPLY}`;
  const currentDraft = store.getters['draftMessages/get'](key);
  const message = [currentDraft, url].filter(Boolean).join('\n');

  store.dispatch('draftMessages/set', { key, message });
  openConversation(card, {});
};

const handleRealtimeCardUpdated = async data => {
  if (Object.keys(currentFilterParams()).length > 0) {
    await refreshStageFirstPage(data.stage_id);
    return;
  }

  try {
    const response = await KanbanBoardsAPI.showCardById(
      selectedBoard.value.id,
      data.card_id
    );
    const card = normalizePayload(response.data);

    if (card.active === false || !patchVisibleCard(card)) {
      await refreshStageFirstPage(data.stage_id);
    }
  } catch {
    await refreshStageFirstPage(data.stage_id);
  }
};

const handleRealtimeKanbanEvent = ({ event, data } = {}) => {
  if (!selectedBoard.value?.id || data?.board_id !== selectedBoard.value.id) {
    return;
  }

  if (boardRefreshEvents.has(event)) {
    refreshSelectedBoard();
    return;
  }

  if (event === 'kanban.card.created' || event === 'kanban.card.deleted') {
    refreshStageFirstPage(data.stage_id);
    return;
  }

  if (event === 'kanban.card.reordered') {
    if (data.source_stage_id === data.target_stage_id) {
      refreshStageFirstPage(data.source_stage_id);
      return;
    }

    refreshStageFirstPages([data.source_stage_id, data.target_stage_id]);
    return;
  }

  if (event === 'kanban.card.updated') {
    handleRealtimeCardUpdated(data);
  }
};

watch(activeBoardId, (boardId, previousBoardId) => {
  if (!boards.value.length) return;

  if (previousBoardId && previousBoardId !== boardId) {
    selectedInboxIds.value = [];
    selectedAssigneeIds.value = [];
    selectedNextActionFilter.value = '';
    selectedStatusFilter.value = '';
    searchInput.value = '';
    selectedSearch.value = '';
    selectedSort.value = '';
    selectedSavedFilterId.value = '';
  }

  isBoardDropdownOpen.value = false;
  showBoard(boardId);
});

watch(selectedOpportunityCardId, async cardId => {
  if (cardId) {
    await nextTick();
    document.querySelector('[data-testid="kanban-opportunity-close"]')?.focus();
    return;
  }

  await nextTick();
  opportunityTriggerElement.value?.focus?.();
  opportunityTriggerElement.value = null;
});

watch(requestedOpportunityCardId, cardId => {
  if (cardId && selectedBoard.value) {
    selectedOpportunityCardId.value = cardId;
  }
});

onMounted(() => {
  emitter.on(BUS_EVENTS.KANBAN_REALTIME_EVENT, handleRealtimeKanbanEvent);
  window.addEventListener('keydown', handleOpportunityKeydown);
  fetchBoards();
});

onUnmounted(() => {
  emitter.off(BUS_EVENTS.KANBAN_REALTIME_EVENT, handleRealtimeKanbanEvent);
  window.removeEventListener('keydown', handleOpportunityKeydown);
});
</script>

<template>
  <main class="flex h-full min-h-0 w-full bg-n-surface-1 text-n-slate-12">
    <section class="flex min-w-0 flex-1 flex-col">
      <header
        data-testid="kanban-workspace-header"
        class="relative grid gap-3 border-b border-n-weak px-4 py-3 lg:px-6"
      >
        <div
          data-testid="kanban-workspace-primary-row"
          class="grid min-w-0 grid-cols-[minmax(0,1fr)_auto] items-center gap-2 lg:grid-cols-[minmax(12rem,auto)_minmax(16rem,1fr)_auto] lg:gap-3"
        >
          <div class="min-w-0 flex-1">
            <OnClickOutside @trigger="isBoardDropdownOpen = false">
              <div class="relative inline-flex max-w-full flex-col">
                <button
                  type="button"
                  data-testid="kanban-board-switcher"
                  class="inline-flex max-w-full items-center gap-2 rounded-md px-1 py-1 text-left text-xl font-medium text-n-slate-12 outline-none focus:ring-2 focus:ring-n-brand/40 disabled:cursor-not-allowed disabled:opacity-50"
                  :disabled="!hasBoards"
                  @click="
                    isBoardDropdownOpen =
                      hasMultipleBoards && !isBoardDropdownOpen
                  "
                >
                  <span class="truncate">{{ currentBoardName }}</span>
                  <i class="i-lucide-chevron-down size-5 text-n-slate-11" />
                </button>
                <div
                  v-if="isBoardDropdownOpen"
                  data-testid="kanban-board-switcher-dropdown"
                  class="absolute left-0 top-full z-10 mt-2 w-96 max-w-[calc(100vw-2rem)] overflow-hidden rounded-lg border border-n-weak bg-n-solid-1 shadow-sm"
                >
                  <button
                    v-for="board in boards"
                    :key="board.id"
                    type="button"
                    class="flex w-full items-center justify-between gap-3 px-4 py-3 text-left text-sm text-n-slate-12 outline-none hover:bg-n-alpha-1 focus:bg-n-alpha-1 focus:ring-2 focus:ring-inset focus:ring-n-brand/40"
                    @click="selectBoard(board.id)"
                  >
                    <span
                      class="overflow-hidden text-ellipsis whitespace-nowrap"
                      :title="board.name"
                    >
                      {{ board.name }}
                    </span>
                    <i
                      v-if="board.id === activeBoardId"
                      class="i-lucide-check size-4 flex-shrink-0 text-n-brand"
                    />
                  </button>
                </div>
              </div>
            </OnClickOutside>
          </div>
          <template v-if="selectedBoard">
            <div
              class="col-span-full order-3 min-w-0 self-center md:order-2 lg:col-span-1"
            >
              <label
                class="block min-w-0"
                @click="openFilters"
                @focusin="openFilters"
              >
                <span class="sr-only">
                  {{ t('KANBAN.FILTERS.SEARCH_LABEL') }}
                </span>
                <div
                  class="relative z-10 flex h-9 min-w-0 w-full items-center overflow-hidden rounded-md border border-n-weak bg-n-surface-1 px-2 shadow-sm"
                >
                  <i
                    class="i-lucide-search size-4 flex-shrink-0 text-n-slate-10"
                  />
                  <input
                    v-model="searchInput"
                    type="search"
                    data-testid="kanban-search-input"
                    class="h-full min-w-0 flex-1 border-0 bg-n-surface-1 px-2 text-sm text-n-slate-12 outline-none focus:ring-2 focus:ring-inset focus:ring-n-brand/30"
                    :placeholder="t('KANBAN.FILTERS.SEARCH_PLACEHOLDER')"
                    :aria-expanded="showFiltersPanel"
                    aria-controls="kanban-filter-panel"
                    aria-haspopup="dialog"
                    @keydown.escape.stop="showFiltersPanel = false"
                    @keyup.enter="applySearch"
                  />
                  <button
                    type="button"
                    data-testid="kanban-apply-search"
                    class="flex size-7 shrink-0 items-center justify-center rounded-md text-n-slate-10 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40"
                    :aria-label="t('KANBAN.FILTERS.APPLY_SEARCH')"
                    :title="t('KANBAN.FILTERS.APPLY_SEARCH')"
                    @click="applySearch"
                  >
                    <i class="i-lucide-arrow-right size-4" />
                  </button>
                  <button
                    v-if="searchInput || selectedSearch"
                    type="button"
                    data-testid="kanban-clear-search"
                    class="flex size-7 shrink-0 items-center justify-center rounded-md text-n-slate-10 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40"
                    :aria-label="t('KANBAN.FILTERS.CLEAR_SEARCH')"
                    :title="t('KANBAN.FILTERS.CLEAR_SEARCH')"
                    @click="clearSearch"
                  >
                    <i class="i-lucide-x size-4" />
                  </button>
                </div>
              </label>
            </div>
          </template>
          <template v-if="selectedBoard">
            <div
              class="order-2 flex items-center gap-1 self-center justify-self-end md:order-3"
            >
              <button
                type="button"
                data-testid="kanban-quick-create-opportunity"
                class="flex size-10 items-center justify-center rounded-md bg-n-brand text-sm font-medium text-white outline-none hover:bg-n-brand/90 focus:ring-2 focus:ring-n-brand/40 disabled:cursor-not-allowed disabled:opacity-50 sm:size-auto sm:gap-1 sm:px-3 sm:py-2"
                :disabled="!firstStageId"
                :aria-label="t('KANBAN.ACTIONS.NEW_OPPORTUNITY')"
                :title="t('KANBAN.ACTIONS.NEW_OPPORTUNITY')"
                @click="openQuickOpportunityPicker"
              >
                <i class="i-lucide-plus size-4" />
                <span class="sr-only sm:not-sr-only">
                  {{ t('KANBAN.ACTIONS.NEW_OPPORTUNITY') }}
                </span>
              </button>
              <OnClickOutside @trigger="showBoardActionsMenu = false">
                <div class="relative">
                  <button
                    type="button"
                    data-testid="kanban-board-actions-menu"
                    class="flex size-10 items-center justify-center rounded-md text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40"
                    :aria-label="t('KANBAN.ACTIONS.MORE')"
                    :aria-expanded="showBoardActionsMenu"
                    aria-controls="kanban-board-actions-menu-panel"
                    @click="showBoardActionsMenu = !showBoardActionsMenu"
                    @keydown.escape.prevent="showBoardActionsMenu = false"
                  >
                    <i class="i-lucide-ellipsis size-4" />
                  </button>
                  <div
                    v-if="showBoardActionsMenu"
                    id="kanban-board-actions-menu-panel"
                    data-testid="kanban-board-actions-menu-panel"
                    class="absolute right-0 z-30 mt-2 grid min-w-52 gap-1 rounded-lg border border-n-weak bg-n-solid-1 p-1.5 shadow-lg"
                  >
                    <button
                      type="button"
                      data-testid="kanban-open-archived-cards"
                      class="flex items-center gap-2 rounded-md px-2.5 py-2 text-left text-sm text-n-slate-12 outline-none hover:bg-n-alpha-2 focus:ring-2 focus:ring-inset focus:ring-n-brand/40"
                      @click="openArchivedCards"
                    >
                      <i class="i-lucide-archive size-4 text-n-slate-10" />
                      {{ t('KANBAN.ARCHIVE.OPEN') }}
                    </button>
                    <button
                      type="button"
                      data-testid="kanban-create-stage-toggle"
                      class="flex items-center gap-2 rounded-md px-2.5 py-2 text-left text-sm text-n-slate-12 outline-none hover:bg-n-alpha-2 focus:ring-2 focus:ring-inset focus:ring-n-brand/40 disabled:cursor-not-allowed disabled:opacity-50"
                      :disabled="isCreatingStage"
                      @click="createStage"
                    >
                      <i class="i-lucide-plus size-4 text-n-slate-10" />
                      {{ t('KANBAN.ACTIONS.CREATE_STAGE') }}
                    </button>
                    <button
                      type="button"
                      class="flex items-center gap-2 rounded-md px-2.5 py-2 text-left text-sm text-n-slate-12 outline-none hover:bg-n-alpha-2 focus:ring-2 focus:ring-inset focus:ring-n-brand/40"
                      @click="exportFilteredCards"
                    >
                      <i class="i-lucide-download size-4 text-n-slate-10" />
                      {{ t('KANBAN.REPORTS.EXPORT') }}
                    </button>
                    <button
                      type="button"
                      class="flex items-center gap-2 rounded-md px-2.5 py-2 text-left text-sm text-n-slate-12 outline-none hover:bg-n-alpha-2 focus:ring-2 focus:ring-inset focus:ring-n-brand/40"
                      :aria-expanded="showSalesSummary"
                      @click="showSalesSummary = !showSalesSummary"
                    >
                      <i
                        class="i-lucide-chart-no-axes-combined size-4 text-n-slate-10"
                      />
                      {{ t('KANBAN.REPORTS.SUMMARY') }}
                    </button>
                    <template v-if="isAdmin">
                      <div class="my-0.5 border-t border-n-weak" />
                      <button
                        type="button"
                        data-testid="kanban-board-automations-button"
                        class="flex items-center gap-2 rounded-md px-2.5 py-2 text-left text-sm text-n-slate-12 outline-none hover:bg-n-alpha-2 focus:ring-2 focus:ring-inset focus:ring-n-brand/40"
                        @click="openBoardAutomations"
                      >
                        <i class="i-lucide-zap size-4 text-n-slate-10" />
                        {{ t('KANBAN.AUTOMATIONS_WORKSPACE.TITLE') }}
                      </button>
                      <button
                        type="button"
                        data-testid="kanban-board-settings-button"
                        class="flex items-center gap-2 rounded-md px-2.5 py-2 text-left text-sm text-n-slate-12 outline-none hover:bg-n-alpha-2 focus:ring-2 focus:ring-inset focus:ring-n-brand/40"
                        @click="openBoardSettings"
                      >
                        <i class="i-lucide-settings size-4 text-n-slate-10" />
                        {{ t('KANBAN.ACTIONS.BOARD_SETTINGS') }}
                      </button>
                    </template>
                  </div>
                </div>
              </OnClickOutside>
            </div>
          </template>
        </div>

        <template v-if="selectedBoard">
          <div
            data-testid="kanban-workspace-secondary-row"
            class="flex min-w-0 items-center justify-end border-t border-n-weak pt-3"
          >
            <div class="flex min-h-10 items-center gap-1">
              <div
                class="flex items-center rounded-md border border-n-weak bg-n-surface-1 p-0.5"
                :aria-label="t('KANBAN.VIEW.LABEL')"
              >
                <button
                  type="button"
                  data-testid="kanban-view-kanban"
                  class="flex size-8 items-center justify-center rounded-md outline-none focus:ring-2 focus:ring-inset focus:ring-n-brand/40"
                  :class="
                    viewMode === 'kanban'
                      ? 'bg-n-alpha-2 text-n-brand'
                      : 'text-n-slate-11 hover:text-n-slate-12'
                  "
                  :aria-label="t('KANBAN.VIEW.KANBAN')"
                  :aria-pressed="viewMode === 'kanban'"
                  @click="viewMode = 'kanban'"
                >
                  <i class="i-lucide-columns-3 size-4" />
                </button>
                <button
                  type="button"
                  data-testid="kanban-view-list"
                  class="flex size-8 items-center justify-center rounded-md outline-none focus:ring-2 focus:ring-inset focus:ring-n-brand/40"
                  :class="
                    viewMode === 'list'
                      ? 'bg-n-alpha-2 text-n-brand'
                      : 'text-n-slate-11 hover:text-n-slate-12'
                  "
                  :aria-label="t('KANBAN.VIEW.LIST')"
                  :aria-pressed="viewMode === 'list'"
                  @click="viewMode = 'list'"
                >
                  <i class="i-lucide-list size-4" />
                </button>
              </div>
              <button
                type="button"
                data-testid="kanban-open-activity-center"
                class="flex size-9 items-center justify-center rounded-md text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40"
                :aria-label="t('KANBAN.ACTIVITY.OPEN')"
                :title="t('KANBAN.ACTIVITY.OPEN')"
                @click="openActivityCenter"
              >
                <i class="i-lucide-calendar-check-2 size-4" />
              </button>
            </div>
            <div
              v-show="showFiltersPanel"
              id="kanban-filter-panel"
              data-testid="kanban-filter-panel"
              class="absolute left-1/2 top-[4.5rem] z-30 grid w-[min(64rem,calc(100vw-2rem))] min-w-0 -translate-x-1/2 gap-4 rounded-lg border border-n-weak bg-n-solid-1 p-4 shadow-xl lg:grid-cols-[16rem_minmax(0,1fr)]"
              role="dialog"
              :aria-label="t('KANBAN.FILTERS.OPEN_FILTERS')"
              @keydown.escape.stop="showFiltersPanel = false"
            >
              <div
                class="col-span-full flex min-w-0 items-center justify-between gap-3 border-b border-n-weak pb-3"
              >
                <div>
                  <h2 class="mb-0 text-sm font-semibold text-n-slate-12">
                    {{ t('KANBAN.FILTERS.OPEN_FILTERS') }}
                  </h2>
                </div>
                <button
                  type="button"
                  data-testid="kanban-filter-panel-close"
                  class="flex size-9 shrink-0 items-center justify-center rounded-md text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40"
                  :aria-label="t('GENERAL.CLOSE')"
                  @click="showFiltersPanel = false"
                >
                  <i class="i-lucide-x size-4" />
                </button>
              </div>
              <div
                data-testid="kanban-filter-saved-sidebar"
                class="grid min-w-0 content-start gap-2 border-r border-n-weak pr-4 lg:col-span-1"
              >
                <label
                  class="text-xs font-medium text-n-slate-11"
                  for="kanban-saved-filter-select"
                >
                  {{ t('KANBAN.FILTERS.SAVED_FILTERS') }}
                </label>
                <select
                  id="kanban-saved-filter-select"
                  :value="selectedSavedFilterId"
                  data-testid="kanban-saved-filter-select"
                  class="h-9 w-full rounded-md border border-n-weak bg-n-surface-1 px-2 text-sm text-n-slate-12 outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
                  :aria-label="t('KANBAN.FILTERS.SAVED_FILTERS')"
                  @change="applySavedFilter"
                >
                  <option value="">
                    {{ t('KANBAN.FILTERS.SAVED_FILTERS') }}
                  </option>
                  <option
                    v-for="savedFilter in savedFilters"
                    :key="savedFilter.id"
                    :value="String(savedFilter.id)"
                  >
                    {{ savedFilter.name }}
                  </option>
                </select>
                <button
                  type="button"
                  data-testid="kanban-filter-shortcut-open"
                  :aria-pressed="selectedStatusFilter === 'open'"
                  class="flex items-center gap-2 rounded-md px-2 py-1.5 text-left text-sm text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40"
                  @click="updateStatusFilter('open')"
                >
                  <i class="i-lucide-circle-dot size-4" />
                  {{ t('KANBAN.FILTERS.OPEN') }}
                </button>
                <button
                  type="button"
                  data-testid="kanban-filter-shortcut-won"
                  :aria-pressed="selectedStatusFilter === 'won'"
                  class="flex items-center gap-2 rounded-md px-2 py-1.5 text-left text-sm text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40"
                  @click="updateStatusFilter('won')"
                >
                  <i class="i-lucide-circle-check size-4" />
                  {{ t('KANBAN.FILTERS.WON') }}
                </button>
                <button
                  type="button"
                  data-testid="kanban-filter-shortcut-lost"
                  :aria-pressed="selectedStatusFilter === 'lost'"
                  class="flex items-center gap-2 rounded-md px-2 py-1.5 text-left text-sm text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40"
                  @click="updateStatusFilter('lost')"
                >
                  <i class="i-lucide-circle-x size-4" />
                  {{ t('KANBAN.FILTERS.LOST') }}
                </button>
                <div class="my-1 border-t border-n-weak" />
                <button
                  type="button"
                  data-testid="kanban-filter-shortcut-missing"
                  :aria-pressed="selectedNextActionFilter === 'missing'"
                  class="flex items-center gap-2 rounded-md px-2 py-1.5 text-left text-sm text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40"
                  @click="updateNextActionFilter('missing')"
                >
                  <i class="i-lucide-calendar-x-2 size-4" />
                  {{ t('KANBAN.FILTERS.MISSING_NEXT_ACTION') }}
                </button>
                <button
                  type="button"
                  data-testid="kanban-filter-shortcut-overdue"
                  :aria-pressed="selectedNextActionFilter === 'overdue'"
                  class="flex items-center gap-2 rounded-md px-2 py-1.5 text-left text-sm text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40"
                  @click="updateNextActionFilter('overdue')"
                >
                  <i class="i-lucide-clock-3 size-4" />
                  {{ t('KANBAN.FILTERS.OVERDUE') }}
                </button>
              </div>
              <div
                data-testid="kanban-filter-criteria"
                class="grid min-w-0 content-start gap-4"
              >
                <label
                  class="grid gap-1 text-sm font-medium text-n-slate-12"
                  for="kanban-sort-select"
                >
                  {{ t('KANBAN.FILTERS.SORT_LABEL') }}
                  <select
                    id="kanban-sort-select"
                    :value="selectedSort"
                    data-testid="kanban-sort-select"
                    class="h-9 w-full rounded-md border border-n-weak bg-n-surface-1 px-2 text-sm font-normal text-n-slate-12 outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
                    @change="updateSort"
                  >
                    <option
                      v-for="option in sortOptions"
                      :key="option.value || 'default'"
                      :value="option.value"
                    >
                      {{ option.label }}
                    </option>
                  </select>
                </label>
                <div class="flex flex-wrap items-center gap-2">
                  <button
                    v-if="selectedSavedFilter && !showRenameSavedFilterForm"
                    type="button"
                    data-testid="kanban-filter-panel-rename-saved-filter"
                    class="flex h-9 items-center gap-2 rounded-md border border-n-weak px-3 text-sm font-medium text-n-slate-11 outline-none hover:bg-n-alpha-2 focus:ring-2 focus:ring-n-brand/40"
                    @click="openRenameSavedFilter"
                  >
                    <i class="i-lucide-pencil size-4" />
                    {{ t('KANBAN.FILTERS.RENAME_FILTER') }}
                  </button>
                  <button
                    v-if="selectedSavedFilter && !showRenameSavedFilterForm"
                    type="button"
                    data-testid="kanban-filter-panel-delete-saved-filter"
                    class="flex h-9 items-center gap-2 rounded-md border border-n-weak px-3 text-sm font-medium text-n-ruby-11 outline-none hover:bg-n-ruby-2 focus:ring-2 focus:ring-n-ruby-8"
                    @click="showDeleteSavedFilterConfirmation = true"
                  >
                    <i class="i-lucide-trash-2 size-4" />
                    {{ t('KANBAN.FILTERS.DELETE_FILTER') }}
                  </button>
                  <button
                    v-if="hasActiveFilters"
                    type="button"
                    data-testid="kanban-filter-panel-save-filter"
                    class="flex h-9 items-center gap-2 rounded-md bg-n-brand px-3 text-sm font-medium text-white outline-none hover:opacity-90 focus:ring-2 focus:ring-n-brand/40"
                    @click="toggleSaveFilterForm"
                  >
                    <i class="i-lucide-bookmark-plus size-4" />
                    {{ t('KANBAN.FILTERS.SAVE_FILTER') }}
                  </button>
                  <button
                    v-if="hasActiveFilters"
                    type="button"
                    data-testid="kanban-filter-panel-clear-filters"
                    class="flex h-9 items-center gap-2 rounded-md px-3 text-sm font-medium text-n-slate-11 outline-none hover:bg-n-alpha-2 focus:ring-2 focus:ring-n-brand/40"
                    @click="clearFilters"
                  >
                    <i class="i-lucide-filter-x size-4" />
                    {{ t('KANBAN.FILTERS.CLEAR') }}
                  </button>
                </div>
                <label class="grid min-w-0 gap-1">
                  <span class="text-xs font-medium text-n-slate-11">{{
                    t('KANBAN.FILTERS.INBOXES')
                  }}</span>
                  <div class="min-w-0" data-testid="kanban-inbox-filter">
                    <TagMultiSelectComboBox
                      :model-value="selectedInboxIds"
                      :options="inboxFilterOptions"
                      :placeholder="t('KANBAN.SETTINGS.INBOXES.PLACEHOLDER')"
                      :search-placeholder="t('KANBAN.SETTINGS.INBOXES.SEARCH')"
                      :empty-state="t('KANBAN.SETTINGS.INBOXES.EMPTY')"
                      :disabled="!hasInboxFilterOptions"
                      @update:model-value="updateInboxFilter"
                    />
                  </div>
                </label>
                <label class="grid min-w-0 gap-1">
                  <span class="text-xs font-medium text-n-slate-11">{{
                    t('KANBAN.FILTERS.AGENTS')
                  }}</span>
                  <div class="min-w-0" data-testid="kanban-agent-filter">
                    <TagMultiSelectComboBox
                      :model-value="selectedAssigneeIds"
                      :options="agentFilterOptions"
                      :placeholder="t('KANBAN.FILTERS.AGENTS')"
                      :search-placeholder="t('KANBAN.SETTINGS.AGENTS.SEARCH')"
                      :empty-state="t('KANBAN.SETTINGS.AGENTS.EMPTY')"
                      :disabled="!hasAgentFilterOptions"
                      @update:model-value="updateAssigneeFilter"
                    />
                  </div>
                </label>
                <div class="grid min-w-0 gap-4">
                  <fieldset class="grid min-w-0 gap-1">
                    <legend class="text-xs font-medium text-n-slate-11">
                      {{ t('KANBAN.FILTERS.NEXT_ACTION_LABEL') }}
                    </legend>
                    <div class="flex min-w-0 flex-wrap gap-1">
                      <button
                        v-for="option in nextActionFilterOptions"
                        :key="option.value || 'all'"
                        type="button"
                        :data-testid="`kanban-next-action-filter-${option.value || 'all'}`"
                        :aria-pressed="
                          selectedNextActionFilter === option.value
                        "
                        class="rounded-md border px-2.5 py-1.5 text-xs font-medium outline-none transition focus:ring-2 focus:ring-n-brand/40"
                        :class="
                          selectedNextActionFilter === option.value
                            ? 'border-n-brand bg-n-brand text-white'
                            : 'border-n-weak text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12'
                        "
                        @click="updateNextActionFilter(option.value)"
                      >
                        {{ option.label }}
                      </button>
                    </div>
                  </fieldset>
                  <fieldset class="grid min-w-0 gap-1">
                    <legend class="text-xs font-medium text-n-slate-11">
                      {{ t('KANBAN.FILTERS.STATUS_LABEL') }}
                    </legend>
                    <div class="flex min-w-0 flex-wrap gap-1">
                      <button
                        v-for="option in statusFilterOptions"
                        :key="option.value || 'all'"
                        type="button"
                        :data-testid="`kanban-status-filter-${option.value || 'all'}`"
                        :aria-pressed="selectedStatusFilter === option.value"
                        class="rounded-md border px-2.5 py-1.5 text-xs font-medium outline-none transition focus:ring-2 focus:ring-n-brand/40"
                        :class="
                          selectedStatusFilter === option.value
                            ? 'border-n-brand bg-n-brand text-white'
                            : 'border-n-weak text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12'
                        "
                        @click="updateStatusFilter(option.value)"
                      >
                        {{ option.label }}
                      </button>
                    </div>
                  </fieldset>
                </div>

                <div
                  v-if="showRenameSavedFilterForm || showSaveFilterForm"
                  :data-testid="
                    showRenameSavedFilterForm
                      ? 'kanban-rename-saved-filter-form'
                      : 'kanban-save-filter-form'
                  "
                  class="flex min-w-0 flex-wrap items-center gap-2 rounded-md border border-n-weak bg-n-surface-2 p-2"
                >
                  <label class="min-w-48 flex-1">
                    <span class="sr-only">{{
                      t('KANBAN.FILTERS.SAVED_NAME_PROMPT')
                    }}</span>
                    <input
                      v-if="showRenameSavedFilterForm"
                      id="kanban-saved-filter-rename-input"
                      v-model="savedFilterRename"
                      data-testid="kanban-saved-filter-rename-input"
                      type="text"
                      class="h-9 w-full rounded-md border border-n-weak bg-n-surface-1 px-2 text-sm text-n-slate-12 outline-none"
                      :placeholder="t('KANBAN.FILTERS.RENAME_FILTER')"
                      @keyup.enter="renameSavedFilter"
                    />
                    <input
                      v-else
                      id="kanban-save-filter-name"
                      v-model="savedFilterName"
                      data-testid="kanban-save-filter-name"
                      type="text"
                      class="h-9 w-full rounded-md border border-n-weak bg-n-surface-1 px-2 text-sm text-n-slate-12 outline-none"
                      :placeholder="t('KANBAN.FILTERS.SAVED_NAME_PROMPT')"
                      @keyup.enter="saveCurrentFilter"
                    />
                  </label>
                  <button
                    v-if="showRenameSavedFilterForm"
                    type="button"
                    data-testid="kanban-confirm-rename-saved-filter"
                    class="flex size-9 items-center justify-center rounded-md text-n-brand outline-none hover:bg-n-alpha-2 focus:ring-2 focus:ring-n-brand/40 disabled:opacity-50"
                    :disabled="!savedFilterRename.trim()"
                    :aria-label="t('KANBAN.FILTERS.RENAME_FILTER')"
                    @click="renameSavedFilter"
                  >
                    <i class="i-lucide-check size-4" />
                  </button>
                  <button
                    v-else
                    type="button"
                    data-testid="kanban-save-filter-confirm"
                    class="flex size-9 items-center justify-center rounded-md text-n-brand outline-none hover:bg-n-alpha-2 focus:ring-2 focus:ring-n-brand/40 disabled:opacity-50"
                    :disabled="!savedFilterName.trim()"
                    :aria-label="t('KANBAN.FILTERS.SAVE_FILTER')"
                    @click="saveCurrentFilter"
                  >
                    <i class="i-lucide-check size-4" />
                  </button>
                </div>
              </div>
            </div>
          </div>
        </template>
      </header>

      <section
        v-if="salesSummary && showSalesSummary"
        data-testid="kanban-sales-summary"
        class="flex flex-wrap items-center gap-x-5 gap-y-2 border-b border-n-weak px-4 py-2 lg:px-6"
      >
        <span class="text-xs font-semibold text-n-slate-12">
          {{ t('KANBAN.REPORTS.SUMMARY') }}
        </span>
        <div class="flex items-baseline gap-1.5 whitespace-nowrap">
          <span class="text-xs text-n-slate-11">
            {{ t('KANBAN.REPORTS.OPEN') }}
          </span>
          <span class="text-sm font-semibold text-n-slate-12">
            {{ salesSummary.openCount || 0 }}
          </span>
        </div>
        <div class="flex items-baseline gap-1.5 whitespace-nowrap">
          <span class="text-xs text-n-slate-11">
            {{ t('KANBAN.REPORTS.WON') }}
          </span>
          <span class="text-sm font-semibold text-n-slate-12">
            {{ salesSummary.wonCount || 0 }}
          </span>
        </div>
        <div class="flex items-baseline gap-1.5 whitespace-nowrap">
          <span class="text-xs text-n-slate-11">
            {{ t('KANBAN.REPORTS.LOST') }}
          </span>
          <span class="text-sm font-semibold text-n-slate-12">
            {{ salesSummary.lostCount || 0 }}
          </span>
        </div>
        <div class="flex items-baseline gap-1.5 whitespace-nowrap">
          <span class="text-xs text-n-slate-11">
            {{ t('KANBAN.REPORTS.OVERDUE') }}
          </span>
          <span class="text-sm font-semibold text-n-ruby-11">
            {{ salesSummary.overdueCount || 0 }}
          </span>
        </div>
        <div class="flex items-baseline gap-1.5 whitespace-nowrap">
          <span class="text-xs text-n-slate-11">
            {{ t('KANBAN.REPORTS.WON_AMOUNT') }}
          </span>
          <span class="text-sm font-semibold text-n-slate-12">
            {{ formatCurrencyFromCents(salesSummary.wonAmountCents) }}
          </span>
        </div>
        <div
          class="flex items-baseline gap-1.5 whitespace-nowrap"
          :title="t('KANBAN.REPORTS.WEIGHTED_OPEN_AMOUNT')"
        >
          <span class="text-xs text-n-slate-11">
            {{ t('KANBAN.REPORTS.WEIGHTED_OPEN_AMOUNT') }}
          </span>
          <span class="text-sm font-semibold text-n-slate-12">
            {{ formatCurrencyFromCents(salesSummary.weightedOpenAmountCents) }}
          </span>
        </div>
      </section>

      <section
        v-if="selectedCardsCount"
        data-testid="kanban-bulk-toolbar"
        role="region"
        :aria-label="t('KANBAN.BULK.SELECTED', { count: selectedCardsCount })"
        class="flex flex-wrap items-center gap-2 border-b border-n-weak bg-n-surface-2 px-6 py-2"
      >
        <strong class="text-sm text-n-slate-12">
          {{ t('KANBAN.BULK.SELECTED', { count: selectedCardsCount }) }}
        </strong>
        <select
          data-testid="kanban-bulk-stage-select"
          class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-2 text-sm text-n-slate-12 outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
          :aria-label="t('KANBAN.BULK.MOVE')"
          :disabled="isBulkUpdating"
          @change="updateBulkStage"
        >
          <option value="">{{ t('KANBAN.BULK.MOVE') }}</option>
          <option v-for="stage in stages" :key="stage.id" :value="stage.id">
            {{ stage.name }}
          </option>
        </select>
        <select
          data-testid="kanban-bulk-owner-select"
          class="h-9 rounded-md border border-n-weak bg-n-surface-1 px-2 text-sm text-n-slate-12 outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
          :aria-label="t('KANBAN.BULK.ASSIGN')"
          :disabled="isBulkUpdating"
          @change="updateBulkOwner"
        >
          <option value="">{{ t('KANBAN.BULK.ASSIGN') }}</option>
          <option
            v-for="option in agentFilterOptions"
            :key="option.value"
            :value="option.value"
          >
            {{ option.label }}
          </option>
        </select>
        <button
          type="button"
          data-testid="kanban-bulk-won"
          class="flex size-9 items-center justify-center rounded-md text-n-teal-11 outline-none hover:bg-n-teal-2 focus:ring-2 focus:ring-n-teal-8"
          :disabled="isBulkUpdating"
          :aria-label="t('KANBAN.BULK.MARK_WON')"
          :title="t('KANBAN.BULK.MARK_WON')"
          @click="prepareBulkWon"
        >
          <i class="i-lucide-trophy size-4" />
        </button>
        <select
          v-model="bulkLostReason"
          data-testid="kanban-bulk-lost-reason"
          class="h-9 max-w-44 rounded-md border border-n-weak bg-n-surface-1 px-2 text-sm text-n-slate-12 outline-none focus:border-n-brand focus:ring-2 focus:ring-n-brand/20"
          :aria-label="t('KANBAN.BULK.LOST_REASON')"
          :disabled="isBulkUpdating"
        >
          <option value="">{{ t('KANBAN.BULK.LOST_REASON') }}</option>
          <option
            v-for="reason in selectedBoard?.lostReasonOptions || []"
            :key="reason"
            :value="reason"
          >
            {{ reason }}
          </option>
        </select>
        <button
          type="button"
          data-testid="kanban-bulk-lost"
          class="flex size-9 items-center justify-center rounded-md text-n-ruby-11 outline-none hover:bg-n-ruby-2 focus:ring-2 focus:ring-n-ruby-8 disabled:opacity-50"
          :disabled="isBulkUpdating || !bulkLostReason"
          :aria-label="t('KANBAN.BULK.MARK_LOST')"
          :title="t('KANBAN.BULK.MARK_LOST')"
          @click="prepareBulkLost"
        >
          <i class="i-lucide-circle-x size-4" />
        </button>
        <button
          type="button"
          data-testid="kanban-bulk-archive"
          class="flex size-9 items-center justify-center rounded-md text-n-ruby-11 outline-none hover:bg-n-ruby-2 focus:ring-2 focus:ring-n-ruby-8"
          :disabled="isBulkUpdating"
          :aria-label="t('KANBAN.BULK.ARCHIVE')"
          :title="t('KANBAN.BULK.ARCHIVE')"
          @click="showBulkArchiveConfirmation = true"
        >
          <i class="i-lucide-archive size-4" />
        </button>
        <button
          type="button"
          data-testid="kanban-clear-card-selection"
          class="flex size-9 items-center justify-center rounded-md text-n-slate-11 outline-none hover:bg-n-alpha-2 focus:ring-2 focus:ring-n-brand/40"
          :aria-label="t('KANBAN.BULK.CLEAR')"
          :title="t('KANBAN.BULK.CLEAR')"
          @click="clearCardSelection"
        >
          <i class="i-lucide-x size-4" />
        </button>
      </section>
      <p
        v-if="showBulkImpactConfirmation"
        data-testid="kanban-bulk-impact-summary"
        class="mb-0 border-b border-n-weak bg-n-surface-2 px-6 py-2 text-sm text-n-slate-11"
      >
        {{ pendingBulkImpactMessage }}
      </p>
      <p
        v-if="bulkOperationResult"
        data-testid="kanban-bulk-operation-result"
        class="mb-0 border-b border-n-weak px-6 py-2 text-sm"
        :class="
          bulkOperationResult.type === 'error'
            ? 'bg-n-ruby-2 text-n-ruby-11'
            : 'bg-n-teal-2 text-n-teal-11'
        "
        :role="bulkOperationResult.type === 'error' ? 'alert' : 'status'"
      >
        {{ bulkOperationResult.message }}
      </p>

      <div
        v-if="hasError"
        class="flex flex-1 items-center justify-center p-6 text-sm text-n-ruby-11"
      >
        {{ t('KANBAN.ERROR') }}
      </div>

      <div
        v-else-if="isInitialLoading || isFetchingBoard"
        class="flex flex-1 items-center justify-center p-6 text-sm text-n-slate-11"
      >
        {{ t('KANBAN.LOADING_BOARD') }}
      </div>

      <div
        v-else-if="!hasBoards"
        class="flex flex-1 items-center justify-center p-6 text-center"
      >
        <div class="max-w-md">
          <h3 class="text-base font-medium text-n-slate-12">
            {{ t('KANBAN.EMPTY_BOARDS') }}
          </h3>
          <p class="mt-2 text-sm text-n-slate-11">
            {{ t('KANBAN.EMPTY_BOARDS_DESCRIPTION') }}
          </p>
        </div>
      </div>

      <div
        v-else-if="hasBoards && stages.length === 0"
        class="flex flex-1 items-center justify-center p-6 text-center"
      >
        <div class="max-w-md">
          <h3 class="text-base font-medium text-n-slate-12">
            {{ t('KANBAN.EMPTY_STAGES') }}
          </h3>
          <p class="mt-2 text-sm text-n-slate-11">
            {{ t('KANBAN.EMPTY_STAGES_DESCRIPTION') }}
          </p>
        </div>
      </div>

      <KanbanListView
        v-else-if="viewMode === 'list'"
        :stages="stages"
        :selected-card-ids="selectedCardIds"
        :stage-cards-loading="stageCardsLoading"
        :stage-cards-errors="stageCardsErrors"
        @open-details="openDetails"
        @open-conversation="openConversation"
        @toggle-selection="toggleCardSelection"
        @toggle-visible-selection="toggleVisibleCardSelection"
        @load-more-stage-cards="loadMoreStageCards"
      />

      <div v-else class="flex min-h-0 flex-1 overflow-x-auto p-4">
        <Draggable
          v-model="stageListModel"
          item-key="id"
          class="flex min-h-0 gap-4"
          handle=".stage-drag-handle"
          ghost-class="opacity-60"
          chosen-class="opacity-90"
          :animation="180"
          @end="onStageDragEnd"
        >
          <template #item="{ element: stage }">
            <section
              :data-stage-id="stage.id"
              class="flex w-72 flex-shrink-0 flex-col overflow-hidden rounded-lg border border-n-weak bg-n-solid-1"
            >
              <header
                class="stage-drag-handle cursor-grab flex min-h-14 items-center justify-between gap-2 px-3 py-2 text-white"
                :class="getStageHeaderClass(stage)"
              >
                <form
                  v-if="editingStageId === stage.id"
                  class="grid min-w-0 flex-1 gap-2"
                  @submit.prevent="updateStage(stage)"
                >
                  <div class="flex min-w-0 gap-2">
                    <input
                      :ref="element => setStageNameInput(stage.id, element)"
                      v-model="stageNames[stage.id]"
                      type="text"
                      class="min-w-0 flex-1 rounded-md border border-white/30 bg-white/90 px-2 py-1.5 text-sm text-n-slate-12 outline-none focus:border-white"
                      :placeholder="t('KANBAN.ACTIONS.STAGE_NAME_PLACEHOLDER')"
                      @keydown.escape.prevent="cancelEditingStage"
                    />
                    <button
                      type="submit"
                      class="flex size-8 flex-shrink-0 items-center justify-center rounded-md border border-white/30 bg-white/10 text-white outline-none hover:bg-white/20 focus:ring-2 focus:ring-white/70 disabled:cursor-not-allowed disabled:opacity-50"
                      :disabled="
                        !String(stageNames[stage.id] || '').trim() ||
                        !!activeActionKey
                      "
                      :aria-label="t('KANBAN.ACTIONS.SAVE_STAGE')"
                      :title="t('KANBAN.ACTIONS.SAVE_STAGE')"
                    >
                      <i class="i-lucide-check size-4" />
                    </button>
                    <button
                      type="button"
                      class="flex size-8 flex-shrink-0 items-center justify-center rounded-md border border-white/30 bg-white/10 text-white outline-none hover:bg-white/20 focus:ring-2 focus:ring-white/70"
                      :aria-label="t('KANBAN.ACTIONS.CANCEL')"
                      :title="t('KANBAN.ACTIONS.CANCEL')"
                      @click="cancelEditingStage"
                    >
                      <i class="i-lucide-x size-4" />
                    </button>
                  </div>
                  <div
                    class="flex items-center gap-1.5"
                    :aria-label="t('KANBAN.ACTIONS.STAGE_COLOR')"
                  >
                    <button
                      v-for="colorOption in stageColorOptions"
                      :key="colorOption.value"
                      type="button"
                      class="size-5 rounded-full border border-white/40 ring-offset-2"
                      :class="[
                        colorOption.swatchClass,
                        stageColors[stage.id] === colorOption.value
                          ? 'ring-2 ring-white'
                          : 'hover:ring-2 hover:ring-white/70',
                      ]"
                      :aria-label="getSelectStageColorLabel(colorOption)"
                      @click="stageColors[stage.id] = colorOption.value"
                    />
                  </div>
                </form>
                <template v-else>
                  <div class="flex min-w-0 flex-1 items-start gap-2">
                    <i
                      class="mt-0.5 size-4 shrink-0"
                      :class="[getKanbanStageIconOption(stage.icon).iconClass]"
                      aria-hidden="true"
                    />
                    <h3
                      class="min-w-0 break-words text-sm font-medium leading-5"
                    >
                      <span :title="stage.description || stage.name">{{
                        stage.name
                      }}</span>
                    </h3>
                    <button
                      v-if="stage.description"
                      type="button"
                      class="flex size-6 shrink-0 items-center justify-center rounded text-white/80 outline-none hover:bg-white/15 hover:text-white focus:ring-2 focus:ring-white/70"
                      :aria-label="stage.description"
                      :title="stage.description"
                    >
                      <i
                        class="i-lucide-circle-help size-4"
                        aria-hidden="true"
                      />
                    </button>
                    <span
                      class="flex-shrink-0 rounded-full bg-white/20 px-2 py-0.5 text-xs font-medium"
                    >
                      {{ stageCardCount(stage) }}
                    </span>
                    <span
                      v-if="stageOverCapacity(stage)"
                      data-testid="kanban-stage-capacity-alert"
                      class="inline-flex flex-shrink-0 items-center gap-1 rounded-full bg-white/20 px-2 py-0.5 text-xs font-medium"
                      :title="t('KANBAN.STAGE.CAPACITY_ALERT')"
                    >
                      <i class="i-lucide-triangle-alert size-3" />
                      {{ `${stageCardCount(stage)}/${stage.wipLimit}` }}
                    </span>
                  </div>
                  <div class="flex flex-shrink-0 gap-1">
                    <button
                      type="button"
                      class="flex size-8 items-center justify-center rounded-md border border-white/30 bg-white/10 text-white outline-none hover:bg-white/20 focus:ring-2 focus:ring-white/70 disabled:cursor-not-allowed disabled:opacity-50"
                      :disabled="!!activeActionKey"
                      :aria-label="t('KANBAN.ACTIONS.EDIT_STAGE')"
                      @click="startEditingStage(stage)"
                    >
                      <i class="i-lucide-pencil size-4" />
                    </button>
                    <button
                      type="button"
                      class="flex size-8 items-center justify-center rounded-md border border-white/30 bg-white/10 text-white outline-none hover:bg-white/20 focus:ring-2 focus:ring-white/70 disabled:cursor-not-allowed disabled:opacity-50"
                      :disabled="!!activeActionKey"
                      :aria-label="t('KANBAN.ACTIONS.REMOVE_STAGE')"
                      @click="openRemoveStageConfirmation(stage)"
                    >
                      <i class="i-lucide-x size-4" />
                    </button>
                  </div>
                </template>
              </header>

              <div
                class="flex min-h-0 flex-1 flex-col gap-2 overflow-y-auto bg-n-solid-1 p-3"
              >
                <button
                  type="button"
                  data-testid="kanban-add-item-button"
                  :data-stage-id="stage.id"
                  class="no-drag flex w-full items-center justify-center gap-1 rounded-md border border-dashed border-n-weak bg-n-alpha-1 px-3 py-2 text-sm font-medium text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40 disabled:cursor-not-allowed disabled:opacity-50"
                  :disabled="!!activeActionKey"
                  :aria-expanded="activeAddItemStageId === stage.id"
                  :aria-controls="`kanban-add-item-panel-${stage.id}`"
                  :title="t('KANBAN.ACTIONS.ADD_ITEM')"
                  @click="toggleAddItemPicker(stage)"
                >
                  <i class="i-lucide-plus size-4" />
                  {{ t('KANBAN.ACTIONS.ADD_ITEM') }}
                </button>

                <KanbanOpportunityPicker
                  v-if="activeAddItemStageId === stage.id"
                  :kanban-board-id="selectedBoard.id"
                  :kanban-stage-id="stage.id"
                  @created="refreshStageFirstPage(stage.id)"
                  @close="closeAddItemPicker"
                />

                <Draggable
                  :list="stage.cards"
                  item-key="id"
                  class="flex min-h-48 flex-1 flex-col gap-2 rounded-md"
                  :group="{ name: 'kanban-cards' }"
                  handle=".card-drag-handle"
                  :filter="cardDragFilter"
                  :prevent-on-filter="false"
                  :empty-insert-threshold="80"
                  :swap-threshold="0.65"
                  fallback-on-body
                  force-fallback
                  :disabled="isCardDragDisabled"
                  ghost-class="opacity-60"
                  chosen-class="opacity-90"
                  :animation="180"
                  @start="onCardDragStart"
                  @change="onCardDragChange(stage, $event)"
                  @end="onCardDragEnd"
                >
                  <p
                    v-if="stage.cards.length === 0"
                    class="pointer-events-none px-1 py-2 text-sm text-n-slate-10"
                  >
                    {{ t('KANBAN.EMPTY_CARDS') }}
                  </p>
                  <template #item="{ element: card }">
                    <KanbanConversationCard
                      :card="card"
                      :stages="stages"
                      :active-action-key="activeActionKey"
                      :selected="selectedCardIds.includes(card.id)"
                      @open-details="openDetails"
                      @open-conversation="openConversation"
                      @remove-card="openRemoveCardConfirmation"
                      @toggle-selection="toggleCardSelection"
                      @move-card="moveCardToStage"
                    />
                  </template>
                </Draggable>

                <div
                  v-if="getStageCardsError(stage.id)"
                  class="text-sm text-n-ruby-11"
                >
                  {{ getStageCardsError(stage.id) }}
                </div>

                <button
                  v-if="stage.pagination?.hasMore"
                  type="button"
                  data-testid="kanban-load-more-cards"
                  :data-stage-id="stage.id"
                  class="no-drag flex w-full items-center justify-center gap-1 rounded-md border border-n-weak bg-n-alpha-1 px-3 py-2 text-sm font-medium text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40 disabled:cursor-not-allowed disabled:opacity-50"
                  :disabled="isStageCardsLoading(stage.id)"
                  @click="loadMoreStageCards(stage)"
                >
                  <i class="i-lucide-loader-2 size-4" />
                  {{
                    isStageCardsLoading(stage.id)
                      ? t('KANBAN.ACTIONS.LOADING_CARDS')
                      : t('KANBAN.ACTIONS.LOAD_MORE_CARDS')
                  }}
                </button>
              </div>
            </section>
          </template>
        </Draggable>
      </div>
    </section>

    <woot-delete-modal
      v-model:show="showBulkArchiveConfirmation"
      :on-close="() => (showBulkArchiveConfirmation = false)"
      :on-confirm="() => performBulkOperation('archive')"
      :title="t('KANBAN.BULK.ARCHIVE_TITLE')"
      :message="t('KANBAN.BULK.ARCHIVE_MESSAGE')"
      :message-value="selectedCardsCount"
      :confirm-text="t('KANBAN.BULK.ARCHIVE')"
      :reject-text="t('KANBAN.ACTIONS.CANCEL')"
    />
    <woot-delete-modal
      v-model:show="showBulkImpactConfirmation"
      :on-close="closeBulkImpactConfirmation"
      :on-confirm="confirmBulkImpact"
      :title="t('KANBAN.BULK.IMPACT_TITLE')"
      :message="pendingBulkImpactMessage"
      :confirm-text="t('KANBAN.BULK.CONFIRM_IMPACT')"
      :reject-text="t('KANBAN.ACTIONS.CANCEL')"
    />
    <woot-delete-modal
      v-model:show="showBulkRestoreConfirmation"
      :on-close="() => (showBulkRestoreConfirmation = false)"
      :on-confirm="bulkRestoreArchivedCards"
      :title="t('KANBAN.BULK.RESTORE_TITLE')"
      :message="t('KANBAN.BULK.RESTORE_MESSAGE')"
      :message-value="selectedArchivedCardIds.length"
      :confirm-text="t('KANBAN.BULK.RESTORE')"
      :reject-text="t('KANBAN.ACTIONS.CANCEL')"
    />
    <woot-delete-modal
      v-model:show="showRemoveCardConfirmation"
      :on-close="closeRemoveCardConfirmation"
      :on-confirm="confirmRemoveCard"
      :title="t('KANBAN.REMOVE_CARD.TITLE')"
      :message="t('KANBAN.REMOVE_CARD.MESSAGE')"
      :message-value="removeCardMessageValue"
      :confirm-text="t('KANBAN.REMOVE_CARD.CONFIRM')"
      :reject-text="t('KANBAN.REMOVE_CARD.CANCEL')"
    />
    <woot-delete-modal
      v-model:show="showDeleteSavedFilterConfirmation"
      :on-close="() => (showDeleteSavedFilterConfirmation = false)"
      :on-confirm="deleteSavedFilter"
      :title="t('KANBAN.FILTERS.DELETE_FILTER')"
      :message="t('KANBAN.FILTERS.DELETE_CONFIRMATION')"
      :confirm-text="t('KANBAN.FILTERS.DELETE_FILTER')"
      :reject-text="t('KANBAN.ACTIONS.CANCEL')"
    />
    <woot-delete-modal
      v-model:show="showRemoveStageConfirmation"
      :on-close="closeRemoveStageConfirmation"
      :on-confirm="confirmRemoveStage"
      :title="t('KANBAN.REMOVE_STAGE.TITLE')"
      :message="t('KANBAN.REMOVE_STAGE.MESSAGE')"
      :message-value="removeStageMessageValue"
      :confirm-text="t('KANBAN.REMOVE_STAGE.CONFIRM')"
      :reject-text="t('KANBAN.REMOVE_STAGE.CANCEL')"
    />

    <woot-modal
      :show="showArchivedCards"
      :show-close-button="false"
      size="modal-medium"
      :on-close="closeArchivedCards"
    >
      <div
        v-if="showArchivedCards"
        data-testid="kanban-archived-cards-modal"
        class="grid gap-4 p-6"
      >
        <div class="flex items-center justify-between gap-3">
          <div>
            <h2 class="mb-0 text-base font-medium text-n-slate-12">
              {{ t('KANBAN.ARCHIVE.TITLE') }}
            </h2>
            <p
              v-if="selectedArchivedCardIds.length"
              class="mb-0 text-xs text-n-slate-11"
            >
              {{
                t('KANBAN.BULK.SELECTED', {
                  count: selectedArchivedCardIds.length,
                })
              }}
            </p>
          </div>
          <button
            v-if="selectedArchivedCardIds.length"
            type="button"
            data-testid="kanban-bulk-restore"
            class="flex items-center gap-1 rounded-md px-2 py-1 text-xs font-medium text-n-brand outline-none hover:bg-n-alpha-2 focus:ring-2 focus:ring-n-brand/40 disabled:opacity-50"
            :disabled="Boolean(restoringCardId)"
            @click="showBulkRestoreConfirmation = true"
          >
            <i class="i-lucide-archive-restore size-4" />
            {{ t('KANBAN.BULK.RESTORE') }}
          </button>
          <button
            type="button"
            class="flex size-8 items-center justify-center rounded-md text-n-slate-11 outline-none hover:bg-n-alpha-2 focus:ring-2 focus:ring-n-brand/40"
            :aria-label="t('KANBAN.ACTIONS.CLOSE')"
            @click="closeArchivedCards"
          >
            <i class="i-lucide-x size-4" />
          </button>
        </div>
        <p v-if="isLoadingArchivedCards" class="mb-0 text-sm text-n-slate-11">
          {{ t('KANBAN.ARCHIVE.LOADING') }}
        </p>
        <p
          v-else-if="!archivedCards.length"
          class="mb-0 rounded-md border border-dashed border-n-weak p-4 text-sm text-n-slate-11"
        >
          {{ t('KANBAN.ARCHIVE.EMPTY') }}
        </p>
        <div v-else class="grid max-h-96 gap-2 overflow-y-auto">
          <article
            v-for="card in archivedCards"
            :key="card.id"
            class="flex items-center justify-between gap-3 rounded-md border border-n-weak p-3"
          >
            <input
              type="checkbox"
              :checked="selectedArchivedCardIds.includes(card.id)"
              :aria-label="card.subject"
              class="size-4 flex-none rounded border-n-weak text-n-brand focus:ring-n-brand"
              @change="toggleArchivedCardSelection(card, $event.target.checked)"
            />
            <div class="min-w-0">
              <p class="mb-0 truncate text-sm font-medium text-n-slate-12">
                {{ card.subject }}
              </p>
              <p class="mb-0 truncate text-xs text-n-slate-11">
                {{ card.contactName }}
                {{ t('KANBAN.ARCHIVE.STAGE_SEPARATOR') }}
                {{ card.stageName }}
              </p>
            </div>
            <button
              type="button"
              :data-testid="`kanban-restore-card-${card.id}`"
              class="flex size-9 flex-none items-center justify-center rounded-md text-n-brand outline-none hover:bg-n-alpha-2 focus:ring-2 focus:ring-n-brand/40 disabled:opacity-50"
              :disabled="Boolean(restoringCardId)"
              :aria-label="t('KANBAN.ARCHIVE.RESTORE')"
              :title="t('KANBAN.ARCHIVE.RESTORE')"
              @click="restoreArchivedCard(card)"
            >
              <i class="i-lucide-archive-restore size-4" />
            </button>
          </article>
        </div>
      </div>
    </woot-modal>

    <woot-modal
      :show="!!pendingAssistedMove"
      :show-close-button="false"
      size="modal-small"
      :on-close="closeAssistedMove"
    >
      <div
        v-if="pendingAssistedMove"
        data-testid="kanban-assisted-move-modal"
        class="grid gap-4 p-6"
      >
        <div>
          <h2 class="text-base font-medium text-n-slate-12">
            {{ t('KANBAN.ASSISTED_MOVE.TITLE') }}
          </h2>
          <p class="mt-1 text-sm text-n-slate-11">
            {{ t('KANBAN.ASSISTED_MOVE.DESCRIPTION') }}
          </p>
        </div>
        <label
          v-for="fieldKey in pendingAssistedMove.missingFields"
          :key="fieldKey"
          class="grid gap-1 text-sm font-medium text-n-slate-12"
        >
          {{ assistedFieldDefinition(fieldKey)?.label || fieldKey }}
          <select
            v-if="
              ['select', 'boolean'].includes(
                assistedFieldDefinition(fieldKey)?.fieldType ||
                  assistedFieldDefinition(fieldKey)?.field_type
              )
            "
            v-model="assistedMoveValues[fieldKey]"
            :data-testid="`kanban-assisted-field-${fieldKey}`"
            class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm font-normal text-n-slate-12 outline-none focus:border-n-brand"
          >
            <option value="" disabled>
              {{ t('KANBAN.ASSISTED_MOVE.SELECT_VALUE') }}
            </option>
            <option
              v-for="option in assistedFieldDefinition(fieldKey)?.options || []"
              :key="String(option)"
              :value="option"
            >
              {{ option }}
            </option>
          </select>
          <input
            v-else
            v-model="assistedMoveValues[fieldKey]"
            :data-testid="`kanban-assisted-field-${fieldKey}`"
            :type="assistedInputType(assistedFieldDefinition(fieldKey))"
            class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm font-normal text-n-slate-12 outline-none focus:border-n-brand"
          />
        </label>
        <div class="flex justify-end gap-2">
          <button
            type="button"
            class="rounded-md px-3 py-2 text-sm font-medium text-n-slate-11 outline-none hover:bg-n-alpha-2 focus:ring-2 focus:ring-n-brand/40"
            @click="closeAssistedMove"
          >
            {{ t('KANBAN.ACTIONS.CANCEL') }}
          </button>
          <button
            type="button"
            data-testid="kanban-assisted-move-confirm"
            class="rounded-md bg-n-brand px-3 py-2 text-sm font-medium text-white outline-none hover:bg-n-brand-hover focus:ring-2 focus:ring-n-brand/40 disabled:opacity-50"
            :disabled="isPersistingCardDrag"
            @click="confirmAssistedMove"
          >
            {{ t('KANBAN.ASSISTED_MOVE.CONFIRM') }}
          </button>
        </div>
      </div>
    </woot-modal>

    <div
      v-if="selectedOpportunityCardId && selectedBoard"
      data-testid="kanban-opportunity-drawer"
      class="fixed inset-0 z-[70] flex justify-end bg-black/10"
      role="dialog"
      aria-modal="true"
      :aria-label="t('KANBAN.OPPORTUNITY_DETAILS.TITLE')"
    >
      <button
        type="button"
        class="absolute inset-0 cursor-default"
        :aria-label="t('KANBAN.ACTIONS.CLOSE')"
        @click="requestOpportunityClose"
      />
      <aside
        class="relative flex h-full w-full max-w-[36rem] flex-col bg-n-background shadow-xl"
      >
        <KanbanOpportunityDetailsModal
          ref="opportunityDetailsModal"
          :board-id="selectedBoard.id"
          :board-name="selectedBoard.name"
          :boards="boards"
          :stages="stages"
          :card-id="selectedOpportunityCardId"
          :next-action-types="selectedBoard.nextActionTypes || []"
          :lost-reason-options="selectedBoard.lostReasonOptions || []"
          :custom-field-definitions="selectedBoard.customFieldDefinitions || []"
          :custom-field-sections="selectedBoard.customFieldSections || []"
          :calendar-enabled="selectedBoard.calendarEnabled"
          :calendar-booking-stage-ids="
            selectedBoard.calendarBookingStageIds || []
          "
          :calendar-procedure-ids="selectedBoard.calendarProcedureIds || []"
          :owner-options="agentFilterOptions"
          :can-manage-fields="isAdmin"
          drawer-mode
          @close="closeOpportunityDetails"
          @updated="onOpportunityUpdated"
          @transferred="onOpportunityTransferred"
          @open-conversation="onOpportunityOpenConversation"
          @send-payment-link="onOpportunitySendPaymentLink"
          @send-form-link="onOpportunitySendFormLink"
          @manage-fields="openFieldSettings"
        />
      </aside>
    </div>

    <KanbanActivityCenter
      v-if="showActivityCenter"
      :stages="stages"
      :board-id="selectedBoard.id"
      :owner-options="agentFilterOptions"
      @close="closeActivityCenter"
      @open-details="
        card => {
          closeActivityCenter({ restoreFocus: false });
          openDetails(card);
        }
      "
    />

    <KanbanConversationDrawer
      :show="!!activeConversationCard"
      :conversation-id="activeConversationCard?.conversationId"
      :title="getContactName(activeConversationCard || {})"
      @close="closeConversationDrawer"
      @open-full-conversation="openFullConversation"
    />

    <woot-modal
      :show="showQuickCreate"
      :show-close-button="false"
      size="modal-small"
      :on-close="() => (showQuickCreate = false)"
    >
      <div
        v-if="showQuickCreate && selectedBoard && firstStageId"
        data-testid="kanban-quick-create-modal"
        class="p-4"
      >
        <div class="mb-3 flex items-start justify-between gap-3">
          <div>
            <h2 class="mb-1 text-base font-semibold text-n-slate-12">
              {{ t('KANBAN.ACTIONS.NEW_OPPORTUNITY') }}
            </h2>
            <p class="mb-0 text-sm text-n-slate-11">
              {{ t('KANBAN.ADD_ITEM.QUICK_CREATE_DESCRIPTION') }}
            </p>
          </div>
          <button
            type="button"
            class="flex size-8 items-center justify-center rounded-md text-n-slate-11 outline-none hover:bg-n-alpha-2 focus:ring-2 focus:ring-n-brand/40"
            :aria-label="t('KANBAN.ACTIONS.CLOSE')"
            @click="showQuickCreate = false"
          >
            <i class="i-lucide-x size-4" />
          </button>
        </div>
        <KanbanOpportunityPicker
          :kanban-board-id="selectedBoard.id"
          :kanban-stage-id="firstStageId"
          @created="refreshStageFirstPage(firstStageId)"
          @close="showQuickCreate = false"
        />
      </div>
    </woot-modal>
  </main>
</template>
