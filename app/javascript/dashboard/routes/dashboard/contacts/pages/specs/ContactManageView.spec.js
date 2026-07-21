import { mount } from '@vue/test-utils';
import ContactManageView from '../ContactManageView.vue';

const mockDispatch = vi.fn(() => Promise.resolve());
const mockRouterBack = vi.fn();
const mockRouterPush = vi.fn();

vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
}));

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: 1, contactId: 7 } }),
  useRouter: () => ({ back: mockRouterBack, push: mockRouterPush }),
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key =>
      ({
        'CONTACTS_LAYOUT.SIDEBAR.TABS.ATTRIBUTES': 'Attributes',
        'CONTACTS_LAYOUT.SIDEBAR.TABS.HISTORY': 'History',
        'CONTACTS_LAYOUT.SIDEBAR.TABS.KANBAN': 'Opportunities',
        'CONTACTS_LAYOUT.SIDEBAR.TABS.NOTES': 'Notes',
        'CONTACTS_LAYOUT.SIDEBAR.TABS.MEDIA': 'Media',
        'CONTACTS_LAYOUT.SIDEBAR.TABS.MERGE': 'Merge',
      })[key] || key,
  }),
}));

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({
    dispatch: mockDispatch,
  }),
  useMapGetter: name => {
    if (name === 'contacts/getContactById') {
      return {
        value: () => ({ id: 7, name: 'Maria Silva' }),
      };
    }

    if (name === 'contacts/getUIFlags') {
      return {
        value: {
          isFetchingItem: false,
          isMerging: false,
          isUpdating: false,
        },
      };
    }

    return { value: [] };
  },
}));

const mountComponent = () =>
  mount(ContactManageView, {
    global: {
      mocks: {
        $t: key => key,
      },
      stubs: {
        ContactsDetailsLayout: {
          template:
            '<section><slot /><slot name="sidebarHeader" /><slot name="sidebar" /></section>',
        },
        Spinner: true,
        ContactDetails: true,
        TabBar: {
          props: ['tabs'],
          template:
            '<nav><span v-for="tab in tabs" :key="tab.value">{{ tab.label }}</span></nav>',
        },
        ContactNotes: true,
        ContactHistory: true,
        ContactMedia: true,
        ContactMerge: true,
        ContactCustomAttributes: true,
        ContactKanbanCards: true,
      },
    },
  });

describe('ContactManageView', () => {
  beforeEach(() => {
    mockDispatch.mockClear();
  });

  it('includes kanban opportunities in the contact sidebar tabs', () => {
    const wrapper = mountComponent();

    expect(wrapper.text()).toContain('Opportunities');
  });
});
