<script setup>
import { computed, nextTick, onBeforeUnmount, ref, watch } from 'vue';
import { onClickOutside } from '@vueuse/core';
import { useI18n } from 'vue-i18n';
import { getKanbanStageIconOption } from 'dashboard/helper/kanbanStageIcons';

const props = defineProps({
  boardId: { type: [Number, String], required: true },
  boardName: { type: String, default: '' },
  boards: { type: Array, default: () => [] },
  stages: { type: Array, default: () => [] },
  selectedStageId: { type: [Number, String], default: null },
  stageEnteredAt: { type: String, default: '' },
});

const emit = defineEmits(['selectStage']);
const { t } = useI18n();
const isOpen = ref(false);
const expandedBoardId = ref(String(props.boardId));

// Na coluna direita da conversa a ficha vive dentro de um painel que corta o
// que passa da borda: o menu abria e ficava invisível. Ele passa a ser
// desenhado no corpo da página, preso ao botão.
const triggerRef = ref(null);
const menuRef = ref(null);
const menuStyle = ref({});

const placeMenu = () => {
  const trigger = triggerRef.value;
  if (!trigger) return;

  const rect = trigger.getBoundingClientRect();
  const width = Math.min(384, window.innerWidth - 32);
  const left = Math.max(
    16,
    Math.min(rect.left, window.innerWidth - width - 16)
  );
  menuStyle.value = {
    position: 'fixed',
    top: `${rect.bottom + 8}px`,
    left: `${left}px`,
    width: `${width}px`,
  };
};

const closeMenu = () => {
  isOpen.value = false;
};

const watchViewport = listen => {
  const method = listen ? 'addEventListener' : 'removeEventListener';
  window[method]('resize', placeMenu);
  window[method]('scroll', placeMenu, true);
};

watch(isOpen, async open => {
  watchViewport(open);
  if (!open) return;

  await nextTick();
  placeMenu();
});

onBeforeUnmount(() => watchViewport(false));
onClickOutside(menuRef, closeMenu, { ignore: [triggerRef] });

// Na coluna direita da conversa a ficha não recebe a lista de funis, e o menu
// abria sem nenhuma etapa. Sem a lista, mostra-se o funil da própria
// oportunidade — que é o que permite mudar de etapa.
const availableBoards = computed(() =>
  props.boards.length
    ? props.boards
    : [{ id: props.boardId, name: props.boardName }]
);
const normalizedBoards = computed(() =>
  availableBoards.value.map(board => ({
    ...board,
    stages:
      String(board.id) === String(props.boardId)
        ? props.stages
        : board.stagesSummary || board.stages_summary || [],
  }))
);
const currentStage = computed(() =>
  props.stages.find(stage => String(stage.id) === String(props.selectedStageId))
);
const daysInStage = computed(() => {
  if (!props.stageEnteredAt) return 0;

  return Math.max(
    0,
    Math.floor(
      (Date.now() - new Date(props.stageEnteredAt).getTime()) / 86400000
    )
  );
});
const daysInStageLabel = computed(() =>
  t('KANBAN.OPPORTUNITY_DETAILS.DAYS_IN_STAGE', { count: daysInStage.value })
);

const toggleMenu = () => {
  isOpen.value = !isOpen.value;
  if (isOpen.value) expandedBoardId.value = String(props.boardId);
};
const toggleBoard = boardId => {
  expandedBoardId.value =
    expandedBoardId.value === String(boardId) ? '' : String(boardId);
};
const selectStage = (boardId, stage) => {
  isOpen.value = false;
  emit('selectStage', {
    boardId: Number(boardId),
    stageId: Number(stage.id),
    stage,
  });
};

watch(
  () => props.boardId,
  boardId => {
    expandedBoardId.value = String(boardId);
  }
);
</script>

<template>
  <div class="relative min-w-0" @keydown.esc.stop="closeMenu">
    <button
      ref="triggerRef"
      type="button"
      data-testid="kanban-opportunity-pipeline-menu-trigger"
      class="flex min-w-[12rem] items-center gap-2 rounded-md px-1 py-0.5 text-left outline-none hover:bg-n-alpha-2 focus:ring-2 focus:ring-n-brand/40"
      :aria-expanded="isOpen"
      aria-haspopup="menu"
      @click="toggleMenu"
    >
      <span class="min-w-0 flex-1">
        <span class="block truncate text-micro text-n-slate-11">{{
          boardName
        }}</span>
        <span class="flex items-start gap-1.5">
          <i
            class="mt-0.5 size-3.5 shrink-0 text-n-slate-11"
            :class="[getKanbanStageIconOption(currentStage?.icon).iconClass]"
            aria-hidden="true"
          />
          <strong
            class="min-w-0 break-words text-xs font-semibold uppercase text-n-slate-12"
            :title="currentStage?.description || currentStage?.name"
          >
            {{ currentStage?.name || t('KANBAN.OPPORTUNITY_DETAILS.STAGE') }}
          </strong>
          <span class="shrink-0 text-micro text-n-slate-11">{{
            daysInStageLabel
          }}</span>
        </span>
      </span>
      <i
        class="i-lucide-chevron-down size-4 shrink-0 text-n-slate-11"
        aria-hidden="true"
      />
    </button>

    <Teleport to="body">
      <div
        v-if="isOpen"
        ref="menuRef"
        data-testid="kanban-opportunity-pipeline-menu"
        class="z-[9999] max-h-[min(28rem,calc(100vh-10rem))] overflow-y-auto rounded-lg border border-solid border-n-weak bg-n-background p-1.5 shadow-xl"
        :style="menuStyle"
        role="menu"
        :aria-label="t('KANBAN.OPPORTUNITY_DETAILS.PIPELINE_AND_STAGE')"
        @keydown.esc.stop="closeMenu"
      >
        <section
          v-for="board in normalizedBoards"
          :key="board.id"
          class="border-b border-n-weak last:border-b-0"
        >
          <button
            type="button"
            class="flex w-full items-center gap-2 px-2 py-2 text-left outline-none hover:bg-n-alpha-2 focus:ring-2 focus:ring-inset focus:ring-n-brand/40"
            :aria-expanded="expandedBoardId === String(board.id)"
            @click="toggleBoard(board.id)"
          >
            <i
              class="size-4 shrink-0 text-n-slate-11"
              :class="
                expandedBoardId === String(board.id)
                  ? 'i-lucide-chevron-down'
                  : 'i-lucide-chevron-right'
              "
              aria-hidden="true"
            />
            <span
              class="min-w-0 flex-1 truncate text-sm font-medium text-n-slate-12"
            >
              {{ board.name }}
            </span>
            <span
              v-if="String(board.id) === String(boardId)"
              class="text-xs text-n-brand"
            >
              {{ t('KANBAN.OPPORTUNITY_DETAILS.CURRENT_PIPELINE') }}
            </span>
          </button>
          <div
            v-if="expandedBoardId === String(board.id)"
            class="grid gap-0.5 pb-1 pl-6"
          >
            <button
              v-for="stage in board.stages"
              :key="stage.id"
              type="button"
              role="menuitem"
              class="flex min-h-8 items-center gap-2 rounded px-2 text-left text-sm outline-none hover:bg-n-alpha-2 focus:ring-2 focus:ring-n-brand/40"
              :class="
                String(stage.id) === String(selectedStageId) &&
                String(board.id) === String(boardId)
                  ? 'bg-n-brand/10 font-medium text-n-brand'
                  : 'text-n-slate-12'
              "
              @click="selectStage(board.id, stage)"
            >
              <i
                class="size-3.5 shrink-0"
                :class="
                  String(stage.id) === String(selectedStageId) &&
                  String(board.id) === String(boardId)
                    ? 'i-lucide-check'
                    : getKanbanStageIconOption(stage.icon).iconClass
                "
                aria-hidden="true"
              />
              <span
                class="min-w-0 break-words"
                :title="stage.description || stage.name"
              >
                {{ stage.name }}
              </span>
            </button>
            <p
              v-if="!board.stages.length"
              class="mb-1 px-2 text-xs text-n-slate-11"
            >
              {{ t('KANBAN.OPPORTUNITY_DETAILS.NO_PIPELINE_STAGES') }}
            </p>
          </div>
        </section>
      </div>
    </Teleport>
  </div>
</template>
