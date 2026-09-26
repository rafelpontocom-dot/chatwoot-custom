<script setup>
/**
 * Raevo · A · Consultório — Visão de funil.
 *
 * A tela que o sistema aprovado desenha para responder «por onde as
 * oportunidades escorregam». Tela própria e não um separador do quadro: o
 * `KanbanView` já passa dos dois mil e duzentos linhas, e este ecrã não partilha
 * estado nenhum com o arrastar de cartões.
 *
 * As quatro contagens aparecem lado a lado e nunca somadas. Entraram e avançaram
 * são fluxo na janela; perdidas é fecho na janela; abertas é o estado de agora.
 * A linha de leitura no cabeçalho diz isso ao utilizador, porque um número de
 * funil mal lido é pior do que nenhum — é sobre ele que se decide onde mexer.
 *
 * A conversão vem nula do servidor quando nada entrou na etapa, e aqui sai como
 * travessão. Zero por cento diria que ninguém avançou, quando não houve ninguém
 * para avançar.
 */
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import camelcaseKeys from 'camelcase-keys';

import KanbanBoardsAPI from 'dashboard/api/kanbanBoards';
import RaevoPageHeader from 'dashboard/components-next/raevo/RaevoPageHeader.vue';
import RaevoStamp from 'dashboard/components-next/raevo/RaevoStamp.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const boardId = computed(() => Number(route.params.boardId));
const isLoading = ref(false);
const error = ref('');
const windowDays = ref(0);
const stages = ref([]);
const boardName = ref('');

const totalMovimento = computed(() =>
  stages.value.reduce((soma, stage) => soma + stage.entered, 0)
);

// O selo da etapa terminal: ganho e perdido não têm avanço para medir, e dizê-lo
// é mais honesto do que mostrar uma conversão de zero.
const SELO_CATEGORIA = {
  won: { variant: 'success', icon: 'i-lucide-check' },
  lost: { variant: 'danger', icon: 'i-lucide-x' },
};

const seloDe = categoria => SELO_CATEGORIA[categoria] || null;

const conversaoDe = stage =>
  stage.conversion === null || stage.conversion === undefined
    ? '—'
    : `${stage.conversion}%`;

const carregar = async () => {
  if (!boardId.value) return;

  isLoading.value = true;
  error.value = '';

  try {
    const [funil, quadro] = await Promise.all([
      KanbanBoardsAPI.getBoardFunnel(boardId.value),
      KanbanBoardsAPI.showBoard(boardId.value),
    ]);
    const dados = camelcaseKeys(funil.data, { deep: true });
    windowDays.value = dados.windowDays;
    stages.value = dados.stages;
    boardName.value = camelcaseKeys(quadro.data, { deep: true }).name || '';
  } catch {
    error.value = t('KANBAN.FUNNEL.ERROR');
  } finally {
    isLoading.value = false;
  }
};

const voltarAoQuadro = () => {
  router.push({
    name: 'kanban_board_show',
    params: { accountId: route.params.accountId, boardId: boardId.value },
  });
};

onMounted(carregar);
</script>

<template>
  <section class="flex h-full flex-col gap-card overflow-y-auto p-3 lg:p-6">
    <RaevoPageHeader
      :eyebrow="t('KANBAN.EYEBROW')"
      :title="t('KANBAN.FUNNEL.TITLE')"
      :badge="t('KANBAN.FUNNEL.WINDOW', { count: windowDays })"
      :subtitle="boardName"
    >
      <template #actions>
        <button
          type="button"
          data-testid="kanban-funnel-back"
          class="inline-flex h-control items-center gap-control-gap rounded-lg px-control text-xs font-medium text-n-slate-11 outline-none hover:bg-n-slate-3 hover:text-n-slate-12 focus-visible:ring-2 focus-visible:ring-n-brand/40"
          @click="voltarAoQuadro"
        >
          <i class="i-lucide-arrow-left size-3" />
          {{ t('KANBAN.FUNNEL.BACK') }}
        </button>
      </template>
    </RaevoPageHeader>

    <p class="text-xs text-n-slate-10">{{ t('KANBAN.FUNNEL.READING') }}</p>

    <p v-if="isLoading" class="text-sm text-n-slate-11">
      {{ t('KANBAN.FUNNEL.LOADING') }}
    </p>

    <div
      v-else-if="error"
      class="flex flex-wrap items-center gap-control-gap rounded-xl border border-solid border-n-ruby-6 bg-n-solid-1 p-card"
    >
      <i class="i-lucide-triangle-alert size-icon text-n-ruby-9" />
      <span class="text-sm text-n-slate-12">{{ error }}</span>
      <button
        type="button"
        data-testid="kanban-funnel-retry"
        class="h-control rounded-lg px-control text-xs font-medium text-n-slate-11 outline-none hover:bg-n-slate-3 hover:text-n-slate-12 focus-visible:ring-2 focus-visible:ring-n-brand/40"
        @click="carregar"
      >
        {{ t('KANBAN.FUNNEL.RETRY') }}
      </button>
    </div>

    <p
      v-else-if="!stages.length"
      data-testid="kanban-funnel-no-stages"
      class="rounded-xl border border-solid border-n-weak bg-n-solid-1 p-card text-sm text-n-slate-11"
    >
      {{ t('KANBAN.FUNNEL.NO_STAGES') }}
    </p>

    <div
      v-else-if="!totalMovimento"
      data-testid="kanban-funnel-empty"
      class="grid gap-1 rounded-xl border border-solid border-n-weak bg-n-solid-1 p-card"
    >
      <span class="text-sm font-medium text-n-slate-12">
        {{ t('KANBAN.FUNNEL.EMPTY') }}
      </span>
      <span class="text-xs text-n-slate-10">
        {{ t('KANBAN.FUNNEL.EMPTY_DESCRIPTION', { count: windowDays }) }}
      </span>
    </div>

    <div
      v-else
      class="overflow-x-auto rounded-xl border border-solid border-n-weak bg-n-solid-1"
    >
      <table class="w-full border-collapse text-sm">
        <thead>
          <tr class="border-b border-solid border-n-weak">
            <th
              scope="col"
              class="h-th px-cell text-left text-micro font-bold uppercase tracking-[0.12em] text-n-slate-10"
            >
              {{ t('KANBAN.FUNNEL.STAGE') }}
            </th>
            <th
              scope="col"
              class="h-th px-cell text-right text-micro font-bold uppercase tracking-[0.12em] text-n-slate-10"
            >
              {{ t('KANBAN.FUNNEL.ENTERED') }}
            </th>
            <th
              scope="col"
              class="h-th px-cell text-right text-micro font-bold uppercase tracking-[0.12em] text-n-slate-10"
            >
              {{ t('KANBAN.FUNNEL.ADVANCED') }}
            </th>
            <th
              scope="col"
              class="h-th min-w-40 px-cell text-left text-micro font-bold uppercase tracking-[0.12em] text-n-slate-10"
            >
              {{ t('KANBAN.FUNNEL.CONVERSION') }}
            </th>
            <th
              scope="col"
              class="h-th px-cell text-right text-micro font-bold uppercase tracking-[0.12em] text-n-slate-10"
            >
              {{ t('KANBAN.FUNNEL.LOST') }}
            </th>
            <th
              scope="col"
              class="h-th px-cell text-right text-micro font-bold uppercase tracking-[0.12em] text-n-slate-10"
            >
              {{ t('KANBAN.FUNNEL.OPEN') }}
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="stage in stages"
            :key="stage.id"
            class="border-b border-solid border-n-weak last:border-b-0"
          >
            <th scope="row" class="p-cell text-left align-middle font-normal">
              <span class="flex flex-wrap items-center gap-control-gap">
                <span class="break-words font-medium text-n-slate-12">
                  {{ stage.name }}
                </span>
                <RaevoStamp
                  v-if="seloDe(stage.category)"
                  size="sm"
                  :variant="seloDe(stage.category).variant"
                  :icon="seloDe(stage.category).icon"
                  :label="t(`KANBAN.REPORTS.${stage.category.toUpperCase()}`)"
                />
              </span>
            </th>
            <td class="p-cell text-right tabular-nums text-n-slate-12">
              {{ stage.entered }}
            </td>
            <td class="p-cell text-right tabular-nums text-n-slate-12">
              {{ stage.advanced }}
            </td>
            <td class="p-cell align-middle">
              <span class="flex items-center gap-control-gap">
                <span
                  aria-hidden="true"
                  class="flex h-1.5 min-w-16 flex-1 overflow-hidden rounded-full bg-n-slate-4"
                >
                  <span
                    class="bg-n-brand"
                    :style="{ flex: `${stage.advanced} 1 0%` }"
                  />
                  <span
                    :style="{ flex: `${stage.entered - stage.advanced} 1 0%` }"
                  />
                </span>
                <span
                  class="whitespace-nowrap tabular-nums text-n-slate-12"
                  :title="
                    stage.conversion === null
                      ? t('KANBAN.FUNNEL.NO_CONVERSION')
                      : ''
                  "
                >
                  {{ conversaoDe(stage) }}
                </span>
              </span>
            </td>
            <td class="p-cell text-right tabular-nums text-n-slate-12">
              {{ stage.lost }}
            </td>
            <td class="p-cell text-right tabular-nums text-n-slate-12">
              {{ stage.open }}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </section>
</template>
