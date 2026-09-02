<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter, useRoute } from 'vue-router';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useAdmin } from 'dashboard/composables/useAdmin';
import Button from 'dashboard/components-next/button/Button.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import { getInboxIconByType } from 'dashboard/helper/inbox';
import { getKanbanStageColorClass } from 'dashboard/helper/kanbanStageColors';
import KanbanBoardsAPI from 'dashboard/api/kanbanBoards';
import KanbanCreateBoardDialog from './KanbanCreateBoardDialog.vue';
import { useKanbanBoardCreation } from './useKanbanBoardCreation';

const { t } = useI18n();
const router = useRouter();
const route = useRoute();
const store = useStore();

const { isAdmin } = useAdmin();

const boards = useMapGetter('kanbanBoards/kanbanBoards');
const isLoading = useMapGetter('kanbanBoards/kanbanBoardsLoading');
const error = useMapGetter('kanbanBoards/kanbanBoardsError');

const hasFetched = ref(false);
const showArchivedBoards = ref(false);
const archivedBoards = ref([]);
const isLoadingArchivedBoards = ref(false);
const restoringBoardId = ref(null);

const hasBoards = computed(() => boards.value.length > 0);
const {
  showCreateBoardDialog,
  createBoardError,
  isCreatingBoard,
  openCreateBoardDialog,
  closeCreateBoardDialog,
  createBoard,
} = useKanbanBoardCreation({ boards, t });

const openBoard = boardId => {
  router.push({
    name: 'kanban_board_show',
    params: {
      accountId: route.params.accountId,
      boardId,
    },
  });
};

const boardCardsCount = board => board.cards_count ?? board.cardsCount ?? 0;
const boardStages = board => board.stages_summary || board.stagesSummary || [];
const boardUsers = board => board.visible_users || board.visibleUsers || [];
const boardInboxes = board =>
  board.allowed_inboxes || board.allowedInboxes || [];
const boardVisibilityMode = board =>
  board.visibility_mode || board.visibilityMode || 'all_agents';
const boardInboxScopeMode = board =>
  board.inbox_scope_mode || board.inboxScopeMode || 'all_inboxes';

const previewItems = (items, limit = 4) => items.slice(0, limit);
const extraItemsCount = (items, limit = 4) => Math.max(items.length - limit, 0);

const inboxIcon = inbox =>
  getInboxIconByType(
    inbox.channel_type || inbox.channelType,
    inbox.medium,
    'line'
  );

const retryFetch = () => {
  store.dispatch('kanbanBoards/fetchBoards');
};

const openArchivedBoards = async () => {
  if (!isAdmin.value || isLoadingArchivedBoards.value) return;

  showArchivedBoards.value = true;
  isLoadingArchivedBoards.value = true;

  try {
    const response = await KanbanBoardsAPI.getArchivedBoards();
    archivedBoards.value = response.data || [];
  } finally {
    isLoadingArchivedBoards.value = false;
  }
};

const restoreBoard = async board => {
  if (!isAdmin.value || restoringBoardId.value) return;

  restoringBoardId.value = board.id;
  try {
    await KanbanBoardsAPI.restoreBoard(board.id);
    archivedBoards.value = archivedBoards.value.filter(
      archivedBoard => archivedBoard.id !== board.id
    );
    await store.dispatch('kanbanBoards/refreshBoards');
  } finally {
    restoringBoardId.value = null;
  }
};

const reorderingBoardId = ref(null);

const canMoveBoard = (board, direction) => {
  const index = boards.value.findIndex(item => item.id === board.id);
  return index >= 0 && Boolean(boards.value[index + direction]);
};

/**
 * A ordem dos funis passa a ser escolhida, não herdada da data de criação.
 *
 * Troca com o vizinho e recarrega: a ordem que aparece é a que ficou gravada,
 * não a que o cliente adivinhou. Subir e descer em vez de arrastar porque a
 * lista é curta e todo o gesto precisa de caminho de teclado.
 */
const moveBoard = async (board, direction) => {
  if (!isAdmin.value || reorderingBoardId.value) return;
  if (!canMoveBoard(board, direction)) return;

  reorderingBoardId.value = board.id;
  try {
    await KanbanBoardsAPI.reorderBoard(board.id, direction < 0 ? 'up' : 'down');
    await store.dispatch('kanbanBoards/refreshBoards');
  } finally {
    reorderingBoardId.value = null;
  }
};

onMounted(async () => {
  hasFetched.value = true;

  try {
    await store.dispatch('kanbanBoards/fetchBoards');
  } catch {
    // Error is handled by the store's error state
  }
});
</script>

<template>
  <main class="flex h-full min-h-0 w-full bg-n-surface-1 text-n-slate-12">
    <div class="mx-auto flex w-full max-w-7xl flex-col gap-4 px-4 py-6 lg:px-8">
      <header class="flex flex-wrap items-center justify-between gap-4">
        <div class="min-w-0">
          <h1 class="text-xl font-semibold text-n-slate-12">
            {{ t('KANBAN.OVERVIEW.TITLE') }}
          </h1>
        </div>
        <div class="flex flex-shrink-0 items-center gap-4">
          <button
            v-if="isAdmin"
            type="button"
            data-testid="overview-open-archived-boards"
            class="flex p-0 size-9 items-center justify-center rounded-md text-n-slate-11 outline-none hover:bg-n-alpha-2 focus:ring-2 focus:ring-n-brand/40"
            :aria-label="t('KANBAN.OVERVIEW.ARCHIVED_BOARDS')"
            :title="t('KANBAN.OVERVIEW.ARCHIVED_BOARDS')"
            @click="openArchivedBoards"
          >
            <i class="i-lucide-archive size-4" />
          </button>
          <Button
            icon="i-lucide-plus"
            data-testid="overview-create-board-button"
            :label="t('KANBAN.OVERVIEW.CREATE_BOARD')"
            color="blue"
            size="sm"
            @click="openCreateBoardDialog"
          />
        </div>
      </header>

      <woot-modal
        :show="showArchivedBoards"
        :show-close-button="false"
        size="modal-medium"
        :on-close="() => (showArchivedBoards = false)"
      >
        <div class="grid gap-4 p-6">
          <div class="flex items-center justify-between gap-3">
            <h2 class="mb-0 text-base font-medium text-n-slate-12">
              {{ t('KANBAN.OVERVIEW.ARCHIVED_BOARDS') }}
            </h2>
            <button
              type="button"
              class="flex p-0 size-8 items-center justify-center rounded-md text-n-slate-11 outline-none hover:bg-n-alpha-2 focus:ring-2 focus:ring-n-brand/40"
              :aria-label="t('KANBAN.ACTIONS.CLOSE')"
              @click="showArchivedBoards = false"
            >
              <i class="i-lucide-x size-4" />
            </button>
          </div>
          <p
            v-if="isLoadingArchivedBoards"
            class="mb-0 text-sm text-n-slate-11"
          >
            {{ t('KANBAN.OVERVIEW.LOADING_ARCHIVED_BOARDS') }}
          </p>
          <p
            v-else-if="!archivedBoards.length"
            class="mb-0 rounded-md border border-dashed border-n-weak p-4 text-sm text-n-slate-11"
          >
            {{ t('KANBAN.OVERVIEW.EMPTY_ARCHIVED_BOARDS') }}
          </p>
          <div v-else class="grid max-h-96 gap-2 overflow-y-auto">
            <article
              v-for="board in archivedBoards"
              :key="board.id"
              class="flex items-center justify-between gap-3 rounded-md border border-n-weak p-3"
            >
              <div class="min-w-0">
                <p class="mb-0 truncate text-sm font-medium text-n-slate-12">
                  {{ board.name }}
                </p>
                <p class="mb-0 text-xs text-n-slate-11">
                  {{ board.cards_count || 0 }}
                  {{ t('KANBAN.OVERVIEW.OPPORTUNITIES') }}
                  <span aria-hidden="true">
                    {{ t('KANBAN.OVERVIEW.SEPARATOR') }}
                  </span>
                  {{ board.stages_count || 0 }}
                  {{ t('KANBAN.OVERVIEW.STAGES') }}
                </p>
              </div>
              <button
                type="button"
                :data-testid="`overview-restore-board-${board.id}`"
                class="flex p-0 size-9 flex-none items-center justify-center rounded-md text-n-brand outline-none hover:bg-n-alpha-2 focus:ring-2 focus:ring-n-brand/40 disabled:opacity-50"
                :disabled="Boolean(restoringBoardId)"
                :aria-label="t('KANBAN.OVERVIEW.RESTORE_BOARD')"
                :title="t('KANBAN.OVERVIEW.RESTORE_BOARD')"
                @click="restoreBoard(board)"
              >
                <i class="i-lucide-archive-restore size-4" />
              </button>
            </article>
          </div>
        </div>
      </woot-modal>

      <KanbanCreateBoardDialog
        v-model="showCreateBoardDialog"
        :is-creating="isCreatingBoard"
        :error="createBoardError"
        @create="createBoard"
        @close="closeCreateBoardDialog"
      />

      <div
        v-if="isLoading"
        class="flex items-center justify-center py-16 text-sm text-n-slate-11"
      >
        {{ t('KANBAN.OVERVIEW.LOADING') }}
      </div>

      <div
        v-else-if="error"
        class="flex flex-col items-center gap-4 py-16 text-center"
      >
        <p class="text-sm text-n-ruby-11" role="alert">
          {{ t('KANBAN.OVERVIEW.ERROR') }}
        </p>
        <Button
          :label="t('KANBAN.ACTIONS.RETRY')"
          color="slate"
          size="sm"
          @click="retryFetch"
        />
      </div>

      <div
        v-else-if="!hasBoards && hasFetched"
        class="flex flex-col items-center gap-4 py-16 text-center"
      >
        <p class="text-sm text-n-slate-11">
          {{
            isAdmin
              ? t('KANBAN.OVERVIEW.EMPTY_ADMIN')
              : t('KANBAN.OVERVIEW.EMPTY_AGENT')
          }}
        </p>
      </div>

      <div
        v-else-if="hasBoards"
        class="overflow-hidden rounded-lg border border-n-weak bg-n-solid-1"
      >
        <div
          v-for="board in boards"
          :key="board.id"
          class="flex items-stretch border-b border-solid border-n-weak last:border-b-0"
        >
          <button
            type="button"
            data-testid="overview-board-card"
            :data-kanban-board-id="board.id"
            class="group flex min-w-0 flex-1 flex-col gap-3 bg-n-solid-1 p-3 text-left transition-colors hover:bg-n-alpha-1 focus:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-n-brand"
            :aria-label="
              t('KANBAN.OVERVIEW.OPEN_FUNNEL', {
                name: board.name,
                count: boardCardsCount(board),
              })
            "
            @click="openBoard(board.id)"
          >
            <div
              class="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between"
            >
              <div class="flex min-w-0 flex-1 flex-wrap items-center gap-2">
                <span class="break-words text-sm font-semibold text-n-slate-12">
                  {{ board.name }}
                </span>
                <span
                  class="inline-flex items-center rounded-full bg-n-alpha-2 px-2 py-0.5 text-xs font-medium text-n-slate-11"
                  data-testid="overview-cards-count"
                >
                  {{
                    t('KANBAN.OVERVIEW.OPPORTUNITIES_COUNT', {
                      count: boardCardsCount(board),
                    })
                  }}
                </span>
              </div>

              <div class="flex flex-wrap items-center gap-2 lg:justify-end">
                <div
                  class="flex items-center"
                  data-testid="overview-agent-list"
                >
                  <template v-if="boardVisibilityMode(board) === 'all_agents'">
                    <span
                      class="inline-flex items-center gap-1.5 rounded-full border border-n-weak bg-n-surface-1 px-2 py-0.5 text-xs font-medium text-n-slate-11"
                    >
                      <i class="i-lucide-users size-3.5" />
                      {{ t('KANBAN.SETTINGS.AGENTS.ALL') }}
                    </span>
                  </template>
                  <template v-else>
                    <Avatar
                      v-for="user in previewItems(boardUsers(board))"
                      :key="user.id"
                      :name="user.name"
                      :src="user.avatar_url || user.avatarUrl || ''"
                      :size="28"
                      rounded-full
                      class="-ml-2 first:ml-0 ring-2 ring-n-surface-2"
                      data-testid="overview-agent-avatar"
                    />
                    <span
                      v-if="extraItemsCount(boardUsers(board))"
                      class="-ml-2 inline-flex size-7 items-center justify-center rounded-full bg-n-alpha-2 text-xs font-medium text-n-slate-11 ring-2 ring-n-surface-2"
                    >
                      {{
                        t('KANBAN.OVERVIEW.EXTRA_COUNT', {
                          count: extraItemsCount(boardUsers(board)),
                        })
                      }}
                    </span>
                  </template>
                </div>

                <div
                  class="flex flex-wrap items-center gap-2"
                  data-testid="overview-inbox-list"
                >
                  <template v-if="boardInboxScopeMode(board) === 'all_inboxes'">
                    <span
                      class="inline-flex items-center gap-1.5 rounded-full border border-n-weak bg-n-surface-1 px-2 py-0.5 text-xs font-medium text-n-slate-11"
                      data-testid="overview-inbox-pill"
                    >
                      <i class="i-lucide-inbox size-3.5" />
                      {{ t('KANBAN.SETTINGS.INBOXES.ALL') }}
                    </span>
                  </template>
                  <template v-else>
                    <span
                      v-for="inbox in previewItems(boardInboxes(board))"
                      :key="inbox.id"
                      class="inline-flex max-w-40 items-center gap-1.5 rounded-full border border-n-weak bg-n-surface-1 px-2.5 py-1 text-xs font-medium text-n-slate-11"
                      data-testid="overview-inbox-pill"
                    >
                      <i
                        :class="inboxIcon(inbox)"
                        class="size-3.5 flex-shrink-0"
                      />
                      <span class="truncate">{{ inbox.name }}</span>
                    </span>
                    <span
                      v-if="extraItemsCount(boardInboxes(board))"
                      class="inline-flex items-center rounded-full bg-n-alpha-2 px-2 py-1 text-xs font-medium text-n-slate-11"
                    >
                      {{
                        t('KANBAN.OVERVIEW.EXTRA_COUNT', {
                          count: extraItemsCount(boardInboxes(board)),
                        })
                      }}
                    </span>
                  </template>
                </div>
              </div>
            </div>

            <div
              v-if="boardStages(board).length"
              class="flex flex-wrap gap-1.5"
              data-testid="overview-stage-list"
            >
              <span
                v-for="stage in boardStages(board)"
                :key="stage.id"
                class="inline-flex max-w-full items-center gap-1.5 rounded-full border border-n-weak bg-n-surface-1 px-2 py-1 text-xs font-medium text-n-slate-11"
                data-testid="overview-stage-pill"
              >
                <span
                  class="size-2 flex-shrink-0 rounded-full"
                  :class="getKanbanStageColorClass(stage.color)"
                />
                <span class="truncate">{{ stage.name }}</span>
                <span
                  class="inline-flex min-w-5 justify-center rounded-full bg-n-alpha-2 px-1.5 py-0.5 text-micro font-semibold text-n-slate-12"
                >
                  {{ stage.cards_count ?? stage.cardsCount ?? 0 }}
                </span>
              </span>
            </div>
            <p v-else class="text-sm text-n-slate-11">
              {{ t('KANBAN.OVERVIEW.EMPTY_STAGES') }}
            </p>
          </button>
          <!--
          A ordem dos funis era a data de criação e mais nada. Subir e descer,
          não arrastar: a lista é curta, e todo o gesto precisa de teclado.
        -->
          <div
            v-if="isAdmin && boards.length > 1"
            class="flex shrink-0 flex-col items-center justify-center gap-1 pr-3"
          >
            <button
              type="button"
              :data-testid="`overview-move-board-${board.id}-up`"
              :disabled="
                !canMoveBoard(board, -1) || reorderingBoardId === board.id
              "
              class="flex p-0 size-7 items-center justify-center rounded-md text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus-visible:ring-2 focus-visible:ring-n-brand/40 disabled:cursor-not-allowed disabled:opacity-40"
              :aria-label="
                t('KANBAN.OVERVIEW.MOVE_FUNNEL_UP', { name: board.name })
              "
              :title="t('KANBAN.OVERVIEW.MOVE_FUNNEL_UP', { name: board.name })"
              @click="moveBoard(board, -1)"
            >
              <i class="i-lucide-chevron-up size-4" />
            </button>
            <button
              type="button"
              :data-testid="`overview-move-board-${board.id}-down`"
              :disabled="
                !canMoveBoard(board, 1) || reorderingBoardId === board.id
              "
              class="flex p-0 size-7 items-center justify-center rounded-md text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus-visible:ring-2 focus-visible:ring-n-brand/40 disabled:cursor-not-allowed disabled:opacity-40"
              :aria-label="
                t('KANBAN.OVERVIEW.MOVE_FUNNEL_DOWN', { name: board.name })
              "
              :title="
                t('KANBAN.OVERVIEW.MOVE_FUNNEL_DOWN', { name: board.name })
              "
              @click="moveBoard(board, 1)"
            >
              <i class="i-lucide-chevron-down size-4" />
            </button>
          </div>
        </div>
      </div>
    </div>
  </main>
</template>
