import { mount } from '@vue/test-utils';
import { h, nextTick } from 'vue';
import ContactPanel from '../ContactPanel.vue';

const mockDispatch = vi.fn();
const mockUpdateUISettings = vi.fn();
const mockToggleSidebarUIState = vi.fn();

vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({
    updateUISettings: mockUpdateUISettings,
    isContactSidebarItemOpen: () => true,
    conversationSidebarItemsOrder: {
      value: [{ name: 'kanban_cards' }],
    },
    toggleSidebarUIState: mockToggleSidebarUIState,
  }),
}));

vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({
    isCloudFeatureEnabled: () => false,
  }),
}));

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({
    dispatch: mockDispatch,
    getters: {
      'inboxes/getInboxById': () => ({ name: 'WhatsApp' }),
    },
  }),
  useMapGetter: name => {
    if (name === 'getSelectedChat') {
      return {
        value: {
          inbox_id: 2,
          meta: {
            channel: 'Channel::Whatsapp',
            sender: { id: 7, name: 'Ana Paula' },
          },
        },
      };
    }

    if (name === 'conversationMetadata/getConversationMetadata') {
      return {
        value: () => ({ additional_attributes: {} }),
      };
    }

    if (name === 'contacts/getContact') {
      return {
        value: () => ({ id: 7, additional_attributes: {} }),
      };
    }

    return { value: [] };
  },
  useFunctionGetter: () => ({ value: { enabled: false } }),
}));

const mountComponent = () =>
  mount(ContactPanel, {
    props: {
      conversationId: 42,
      inboxId: 2,
    },
    global: {
      mocks: {
        $t: key =>
          ({
            'CONVERSATION.SIDEBAR.CONTACT': 'Contact',
            'CONVERSATION_SIDEBAR.ACCORDION.KANBAN': 'Opportunities',
          })[key] || key,
      },
      stubs: {
        AccordionItem: {
          props: ['title'],
          template: '<section><h3>{{ title }}</h3><slot /></section>',
        },
        ContactInfo: true,
        ContactConversations: true,
        ConversationAction: true,
        ConversationParticipant: true,
        ContactNotes: true,
        ConversationInfo: true,
        CustomAttributes: true,
        SharedFiles: true,
        MacrosList: true,
        ShopifyOrdersList: true,
        SidebarActionsHeader: true,
        LinearIssuesList: true,
        LinearSetupCTA: true,
        'woot-feature-toggle': {
          template: '<div><slot /></div>',
        },
        KanbanConversationCards: {
          props: ['conversationId'],
          template:
            '<div data-testid="kanban-conversation-cards">{{ conversationId }}</div>',
        },
        Draggable: {
          props: ['list'],
          setup(props, { slots }) {
            return () =>
              h(
                'div',
                props.list.map(element => slots.item?.({ element }))
              );
          },
        },
      },
    },
  });

describe('ContactPanel', () => {
  beforeEach(() => {
    mockDispatch.mockClear();
    mockUpdateUISettings.mockClear();
    mockToggleSidebarUIState.mockClear();
  });

  it('renders kanban opportunities in the conversation sidebar', async () => {
    const wrapper = mountComponent();

    await nextTick();

    expect(wrapper.text()).toContain('Opportunities');
    expect(
      wrapper.get('[data-testid="kanban-conversation-cards"]').text()
    ).toBe('42');
  });
});
