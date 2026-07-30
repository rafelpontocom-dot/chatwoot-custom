import { shallowMount } from '@vue/test-utils';
import KanbanConversationCard from '../KanbanConversationCard.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, values = {}) => {
      const translations = {
        'KANBAN.CARD.CONVERSATION_ID': `#${values.id}`,
        'KANBAN.CARD.INBOX': `Inbox: ${values.inbox}`,
        'KANBAN.CARD.ASSIGNEE': `Assignee: ${values.assignee}`,
        'KANBAN.CARD.LAST_ACTIVITY': `Last activity: ${values.time}`,
        'KANBAN.CARD.CUSTOM_FIELD': `${values.label}: ${values.value}`,
        'KANBAN.CARD.UNKNOWN_CONTACT': 'Unknown Contact',
        'KANBAN.CARD.UNKNOWN_INBOX': 'Unknown Inbox',
        'KANBAN.CARD.NO_LINKED_CONVERSATION': 'No linked conversation',
        'KANBAN.CARD.NEXT_ACTION.MISSING': 'No next action',
        'KANBAN.CARD.NEXT_ACTION.OVERDUE': 'Overdue',
        'KANBAN.CARD.NEXT_ACTION.DUE_TODAY': 'Today',
        'KANBAN.CARD.NEXT_ACTION.FUTURE': 'Next action',
        'KANBAN.CARD.NEXT_ACTION.CLOSED': 'Closed',
        'KANBAN.ACTIONS.REMOVE_CARD': 'Remove',
        'KANBAN.ACTIONS.OPEN_CARD_DETAILS': 'Open opportunity details',
        'KANBAN.CARD.MOVE_TO_STAGE': 'Move to stage',
      };

      return translations[key] || key;
    },
  }),
}));

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({
    getters: {
      'inboxes/getInboxById': () => ({ name: 'Support Inbox' }),
    },
  }),
}));

vi.mock('shared/helpers/timeHelper', () => ({
  dynamicTime: () => 'just now',
  shortTimestamp: () => 'now',
}));

const buildCard = overrides => ({
  id: 10,
  kanbanStageId: 1,
  subject: 'Enterprise expansion',
  stage_entered_at: '2026-06-05T18:00:00-03:00',
  due_at: '2026-06-07T18:00:00-03:00',
  conversationId: 42,
  conversation: {
    inboxId: 5,
    status: 'open',
    priority: 'high',
    lastActivityAt: 123,
    meta: {
      sender: { id: 7, name: 'Jane Doe', thumbnail: 'jane.png' },
      assignee: { name: 'Agent Smith', thumbnail: 'agent.png' },
    },
    messages: [{ content: 'First message' }],
  },
  ...overrides,
});

const buildManualCard = overrides =>
  buildCard({
    subject: 'Renewal follow-up',
    contact: { id: 11, name: 'Manual Contact' },
    inbox: { id: 12, name: 'Sales Inbox' },
    conversationId: null,
    conversation: null,
    ...overrides,
  });

const mountCard = ({
  card = buildCard(),
  activeActionKey = '',
  stages = [],
} = {}) =>
  shallowMount(KanbanConversationCard, {
    props: {
      card,
      activeActionKey,
      selected: false,
      stages,
    },
    global: {
      stubs: {
        Avatar: {
          name: 'Avatar',
          props: ['name', 'src', 'size', 'roundedFull'],
          template:
            '<span class="avatar-stub">{{ name }} {{ src }} {{ size }}</span>',
        },
        ChannelIcon: {
          name: 'ChannelIcon',
          props: ['inbox'],
          template: '<span class="channel-icon-stub" />',
        },
        InboxName: {
          name: 'InboxName',
          props: ['inbox', 'showIcon'],
          template:
            '<span class="inbox-name-stub">{{ inbox.name }} {{ showIcon }}</span>',
        },
      },
    },
  });

describe('KanbanConversationCard', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders an existing conversation card', () => {
    const wrapper = mountCard();

    expect(wrapper.text()).toContain('Enterprise expansion');
    expect(wrapper.text()).toContain('Jane Doe');
    expect(wrapper.text()).toContain('Agent Smith');
    expect(wrapper.findComponent({ name: 'ChannelIcon' }).exists()).toBe(true);
  });

  it('shows the commercial owner when the opportunity has one', () => {
    const wrapper = mountCard({
      card: buildManualCard({
        owner: { name: 'Ana Comercial', thumbnail: 'ana.png' },
      }),
    });

    expect(wrapper.text()).toContain('Ana Comercial');
  });

  it('does not format an empty opportunity value as zero', () => {
    const wrapper = mountCard({ card: buildCard({ amountCents: '' }) });

    expect(wrapper.find('[data-testid="kanban-card-amount"]').exists()).toBe(
      false
    );
    expect(wrapper.text()).not.toContain('R$ 0,00');
  });

  it('prioritizes the configured next action in the compact summary', () => {
    const wrapper = mountCard({
      card: buildCard({
        nextActionStatus: 'future',
        nextActionType: 'Enviar proposta',
      }),
    });

    expect(
      wrapper.find('[data-testid="kanban-card-next-action"]').text()
    ).toContain('Enviar proposta');
  });

  it('keeps the draggable root intact', () => {
    const wrapper = mountCard();

    expect(wrapper.element.tagName).toBe('ARTICLE');
    expect(wrapper.classes()).toContain('card-drag-handle');
    expect(wrapper.classes()).not.toContain('no-drag');
  });

  it('uses a dense surface for scanning a commercial pipeline', () => {
    const wrapper = mountCard();

    expect(wrapper.classes()).toContain('rounded-lg');
    expect(wrapper.classes()).toContain('p-2.5');
    expect(wrapper.classes()).toContain('shadow-none');
  });

  it('keeps the next action, value and conversation action in a stable card footer', () => {
    const wrapper = mountCard({
      card: buildCard({
        amountCents: 125000,
        nextActionStatus: 'overdue',
        nextActionAt: '2026-07-29T12:00:00-03:00',
      }),
    });

    const footer = wrapper.find('[data-testid="kanban-card-workflow-summary"]');

    expect(footer.exists()).toBe(true);
    expect(footer.classes()).toContain('justify-between');
    expect(
      footer.find('[data-testid="kanban-card-next-action"]').exists()
    ).toBe(true);
    expect(footer.find('[data-testid="kanban-card-amount"]').exists()).toBe(
      true
    );
    expect(
      footer.find('[data-testid="kanban-card-open-conversation"]').exists()
    ).toBe(true);
  });

  it('emits selection without opening the opportunity', async () => {
    const wrapper = mountCard();

    await wrapper.find('[data-testid="kanban-card-select"]').setValue(true);

    expect(wrapper.emitted('toggleSelection')[0]).toEqual([buildCard(), true]);
    expect(wrapper.emitted('openDetails')).toBeUndefined();
  });

  it('provides a keyboard-accessible action to open opportunity details', async () => {
    const wrapper = mountCard();

    await wrapper
      .find('[data-testid="kanban-card-open-details"]')
      .trigger('click');

    expect(wrapper.emitted('openDetails')).toHaveLength(1);
  });

  it('provides a direct action to open the linked conversation', async () => {
    const wrapper = mountCard();

    await wrapper
      .find('[data-testid="kanban-card-open-conversation"]')
      .trigger('click');

    expect(wrapper.emitted('openConversation')).toHaveLength(1);
    expect(wrapper.emitted('openConversation')[0][0]).toEqual(buildCard());
  });

  it('shows the native priority indicator when priority is present', () => {
    const wrapper = mountCard();
    const priorityIcon = wrapper.findComponent({ name: 'CardPriorityIcon' });

    expect(priorityIcon.exists()).toBe(true);
    expect(priorityIcon.props('priority')).toBe('high');
  });

  it.each(['urgent', 'high', 'medium', 'low'])(
    'uses the native priority indicator for %s priority',
    priority => {
      const wrapper = mountCard({
        card: buildCard({
          conversation: {
            ...buildCard().conversation,
            priority,
          },
        }),
      });

      expect(
        wrapper.findComponent({ name: 'CardPriorityIcon' }).props()
      ).toMatchObject({
        priority,
      });
    }
  );

  it('does not render the priority indicator when priority is missing', () => {
    const wrapper = mountCard({
      card: buildCard({
        conversation: {
          ...buildCard().conversation,
          priority: null,
        },
      }),
    });

    expect(wrapper.findComponent({ name: 'CardPriorityIcon' }).exists()).toBe(
      false
    );
  });

  it('does not render the priority indicator for unexpected priority values', () => {
    const wrapper = mountCard({
      card: buildCard({
        conversation: {
          ...buildCard().conversation,
          priority: 'critical',
        },
      }),
    });

    expect(wrapper.findComponent({ name: 'CardPriorityIcon' }).exists()).toBe(
      false
    );
  });

  it('emits openDetails when the card surface is clicked', async () => {
    const card = buildCard();
    const wrapper = mountCard({ card });

    await wrapper.find('article').trigger('click');

    expect(wrapper.emitted('openDetails')).toHaveLength(1);
    expect(wrapper.emitted('openDetails')[0][0]).toEqual(card);
  });

  it('renders subject above contact name with title when subject is present', () => {
    const wrapper = mountCard();
    const text = wrapper.text();
    const subject = wrapper.find('p[title="Enterprise expansion"]');

    expect(subject.exists()).toBe(true);
    expect(text).toContain('Enterprise expansion');
    expect(text.indexOf('Enterprise expansion')).toBeLessThan(
      text.indexOf('Jane Doe')
    );
  });

  it('renders manual-like card contact safely', () => {
    const wrapper = mountCard({ card: buildManualCard() });

    expect(wrapper.text()).toContain('Renewal follow-up');
    expect(wrapper.text()).toContain('Manual Contact');
    expect(wrapper.findComponent({ name: 'CardPriorityIcon' }).exists()).toBe(
      false
    );
  });

  it('renders next action status badge', () => {
    const wrapper = mountCard({
      card: buildManualCard({
        nextActionStatus: 'overdue',
        nextActionAt: '2026-07-20T15:00:00-03:00',
      }),
    });

    const badge = wrapper.find('[data-testid="kanban-card-next-action"]');

    expect(badge.exists()).toBe(true);
    expect(badge.text()).toContain('Overdue');
    expect(badge.text()).toContain('Jul 20');
  });

  it('renders opportunity value without expanding the card with custom fields', () => {
    const wrapper = mountCard({
      card: buildManualCard({
        amountCents: 125050,
        amountCurrency: 'BRL',
        customFieldValues: {
          origem: 'Instagram',
          interno: 'Não exibir',
        },
        compactCustomFields: [
          { key: 'origem', label: 'Origem', value: 'Instagram' },
        ],
      }),
    });

    expect(wrapper.find('[data-testid="kanban-card-amount"]').text()).toContain(
      'R$ 1.250,50'
    );
    expect(
      wrapper.find('[data-testid="kanban-card-custom-fields"]').exists()
    ).toBe(false);
    expect(wrapper.text()).not.toContain('Não exibir');
  });

  it('keeps stage movement out of the dense card surface', () => {
    const wrapper = mountCard({
      stages: [
        { id: 1, name: 'New lead' },
        { id: 2, name: 'Proposal' },
      ],
    });

    expect(
      wrapper.find('[data-testid="kanban-card-move-stage"]').exists()
    ).toBe(false);
  });

  it('emits openDetails even when conversationId is null', async () => {
    const card = buildManualCard();
    const wrapper = mountCard({ card });

    await wrapper.find('article').trigger('click');

    expect(wrapper.emitted('openDetails')).toHaveLength(1);
    expect(wrapper.emitted('openDetails')[0][0]).toEqual(card);
  });

  it('does not emit openConversation from avatar when conversation is missing', async () => {
    const wrapper = mountCard({ card: buildManualCard() });

    await wrapper
      .find('[data-testid="kanban-card-contact-avatar"]')
      .trigger('click');

    expect(wrapper.emitted('openConversation')).toBeUndefined();
    expect(wrapper.emitted('openDetails')).toBeUndefined();
  });

  it('does not emit openDetails when clicking remove button', async () => {
    const wrapper = mountCard();

    await wrapper.find('[data-testid="kanban-card-remove"]').trigger('click');

    expect(wrapper.emitted('openDetails')).toBeUndefined();
    expect(wrapper.emitted('removeCard')).toHaveLength(1);
  });

  it('emits removeCard when the remove action is clicked', async () => {
    const card = buildCard();
    const wrapper = mountCard({ card });

    await wrapper.find('[data-testid="kanban-card-remove"]').trigger('click');

    expect(wrapper.emitted('removeCard')).toEqual([[card]]);
  });

  it('emits openConversation when clicking the contact avatar with a conversation', async () => {
    const card = buildCard();
    const wrapper = mountCard({ card });

    await wrapper
      .find('[data-testid="kanban-card-contact-avatar"]')
      .trigger('click');

    expect(wrapper.emitted('openConversation')).toHaveLength(1);
    expect(wrapper.emitted('openConversation')[0][0]).toEqual(card);
    expect(wrapper.emitted('openDetails')).toBeUndefined();
  });

  it('marks remove button as no-drag', async () => {
    const wrapper = mountCard();

    expect(
      wrapper.find('[data-testid="kanban-card-remove"]').classes()
    ).toContain('no-drag');
  });

  it('marks remove button as accessible', () => {
    const wrapper = mountCard();
    const removeButton = wrapper.find('[data-testid="kanban-card-remove"]');

    expect(removeButton.attributes('aria-label')).toBe('Remove');
    expect(removeButton.attributes('title')).toBe('Remove');
  });

  it('does not render an edit button', () => {
    const wrapper = mountCard();

    expect(wrapper.find('.i-lucide-pencil').exists()).toBe(false);
    expect(wrapper.text()).not.toContain('Edit');
  });

  it('renders a channel indicator without an inbox text pill', () => {
    const wrapper = mountCard();

    expect(wrapper.findComponent({ name: 'ChannelIcon' }).exists()).toBe(true);
    expect(wrapper.findComponent({ name: 'InboxName' }).exists()).toBe(false);
  });

  it('does not leave optional rows when optional values are missing', () => {
    const wrapper = mountCard({
      card: buildCard({
        subject: '',
        stage_entered_at: null,
        due_at: null,
        conversation: {
          ...buildCard().conversation,
          priority: null,
          meta: {
            ...buildCard().conversation.meta,
            assignee: null,
          },
        },
      }),
    });

    expect(wrapper.find('p[title]').exists()).toBe(false);
    expect(wrapper.find('[data-testid="kanban-card-meta"]').exists()).toBe(
      false
    );
    expect(wrapper.findAllComponents({ name: 'Avatar' })).toHaveLength(1);
  });

  it('does not render inline Contact Notes UI', () => {
    const wrapper = mountCard();

    expect(wrapper.find('textarea').exists()).toBe(false);
    expect(wrapper.text()).not.toContain('Show notes');
    expect(wrapper.text()).not.toContain('Hide notes');
  });
});
