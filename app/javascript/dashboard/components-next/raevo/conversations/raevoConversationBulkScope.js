// RAEVO (17/10, 123jpnbcxh4) — o recorte que a lista está a mostrar, no formato que
// o servidor entende, para «selecionar as N do filtro» agir sobre exatamente isso.
//
// Pasta guardada e filtro avançado mandam a mesma `query` que a lista manda ao
// pedir as conversas; sem eles vão os filtros da aba, sem a página.
export const raevoConversationBulkScope = ({
  folderQuery = null,
  appliedFiltersQuery = null,
  filters = {},
}) => {
  if (folderQuery?.payload?.length) return { query: folderQuery.payload };
  if (appliedFiltersQuery?.payload?.length) {
    return { query: appliedFiltersQuery.payload };
  }

  const {
    inboxId,
    teamId,
    status,
    assigneeType,
    conversationType,
    sortBy,
    labels,
  } = filters;
  const snake = {
    inbox_id: inboxId,
    team_id: teamId,
    status,
    assignee_type: assigneeType,
    conversation_type: conversationType,
    sort_by: sortBy,
    labels,
  };
  return {
    filters: Object.fromEntries(
      Object.entries(snake).filter(([, value]) => value !== undefined)
    ),
  };
};
