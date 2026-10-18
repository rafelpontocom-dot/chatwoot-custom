import { raevoConversationBulkScope } from '../raevoConversationBulkScope';

describe('raevoConversationBulkScope', () => {
  const payload = [{ attribute_key: 'status', values: ['open'] }];

  it('sends the saved folder query when a folder is open', () => {
    expect(
      raevoConversationBulkScope({
        folderQuery: { payload },
        filters: { status: 'open' },
      })
    ).toEqual({ query: payload });
  });

  it('sends the advanced filter query when one is applied', () => {
    expect(
      raevoConversationBulkScope({ appliedFiltersQuery: { payload } })
    ).toEqual({ query: payload });
  });

  it('sends the tab filters, in snake case and without the page', () => {
    expect(
      raevoConversationBulkScope({
        filters: {
          inboxId: 3,
          assigneeType: 'all',
          status: 'open',
          page: 2,
          labels: ['retorno'],
          teamId: undefined,
        },
      })
    ).toEqual({
      filters: {
        inbox_id: 3,
        assignee_type: 'all',
        status: 'open',
        labels: ['retorno'],
      },
    });
  });
});
