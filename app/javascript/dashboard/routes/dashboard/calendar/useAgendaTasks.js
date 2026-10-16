import { ref, watch } from 'vue';
import KanbanBoardsAPI from 'dashboard/api/kanbanBoards';

/**
 * As tarefas dos leads na Agenda (5m): as próximas ações abertas das
 * oportunidades no período da grelha, e as que já passaram.
 *
 * Desligadas por omissão e, ligadas, só as minhas — as duas escolhas da
 * aprovação de 08/10. Só se pede ao servidor quando estão à vista; um pedido
 * antigo que chega tarde não apaga o mais recente.
 */
export function useAgendaTasks(range) {
  const visible = ref(false);
  const scope = ref('mine');
  const tasks = ref([]);
  const overdue = ref({ count: 0, count_capped: false, items: [] });
  const isLoading = ref(false);
  const hasError = ref(false);
  let latestRequest = 0;

  const load = async () => {
    latestRequest += 1;
    const request = latestRequest;
    if (!visible.value) {
      tasks.value = [];
      overdue.value = { count: 0, count_capped: false, items: [] };
      isLoading.value = false;
      return;
    }
    isLoading.value = true;
    hasError.value = false;
    const { startsAt, endsAt } = range.value;
    try {
      const { data } = await KanbanBoardsAPI.getNextActions({
        starts_at: startsAt.toISOString(),
        ends_at: endsAt.toISOString(),
        scope: scope.value === 'team' ? 'team' : undefined,
      });
      if (request !== latestRequest) return;
      tasks.value = data.tasks || [];
      overdue.value = data.overdue || overdue.value;
    } catch {
      if (request !== latestRequest) return;
      tasks.value = [];
      hasError.value = true;
    } finally {
      if (request === latestRequest) isLoading.value = false;
    }
  };

  watch(
    [
      visible,
      scope,
      () => range.value.startsAt.getTime(),
      () => range.value.endsAt.getTime(),
    ],
    load
  );

  return { visible, scope, tasks, overdue, isLoading, hasError, load };
}
