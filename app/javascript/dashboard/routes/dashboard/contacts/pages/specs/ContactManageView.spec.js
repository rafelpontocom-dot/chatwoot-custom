import { mount } from '@vue/test-utils';
import ContactManageView from '../ContactManageView.vue';

const mockDispatch = vi.fn(() => Promise.resolve());
let mockRole = 'administrator';
let mockUISettings = {};
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
  // `useAdmin` lê o papel daqui: sem isto a vista nem monta.
  useStoreGetters: () => ({
    getCurrentRole: { value: mockRole },
    getUISettings: { value: mockUISettings },
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
        FluentIcon: true,
        EmojiOrIcon: true,
        ContactNotes: true,
        ContactHistory: { template: '<p data-testid="history" />' },
        ContactMedia: true,
        ContactMerge: true,
        ContactCustomAttributes: { template: '<p data-testid="attributes" />' },
        ContactKanbanCards: { template: '<p data-testid="kanban" />' },
        ContactFormSubmissions: true,
        FormsSubmissionDetailsDialog: true,
      },
    },
  });

describe('ContactManageView', () => {
  beforeEach(() => {
    mockDispatch.mockClear();
    mockRole = 'administrator';
    mockUISettings = {};
  });

  it('includes kanban opportunities in the contact sidebar sections', () => {
    const wrapper = mountComponent();

    expect(wrapper.text()).toContain('Opportunities');
  });

  // A ficha de respostas é de administração, como em `FormSubmissionPolicy`:
  // um agente atende conversas, não lê fichas de pacientes.
  it('offers the form responses section to an administrator', () => {
    const wrapper = mountComponent();

    expect(wrapper.text()).toContain('CONTACTS_LAYOUT.SIDEBAR.TABS.FORMS');
  });

  it('keeps the form responses section away from an agent', () => {
    mockRole = 'agent';

    const wrapper = mountComponent();

    expect(wrapper.text()).not.toContain('CONTACTS_LAYOUT.SIDEBAR.TABS.FORMS');
  });

  // 123jpnbcxpd: a tira de sete abas rolava sem avisar; agora são secções que
  // abrem e fecham, como a lateral do contacto na conversa.
  it('stacks the sections, with the opportunities and the history open', () => {
    const wrapper = mountComponent();

    expect(
      wrapper.findAll('[data-testid^="raevo-contact-section-"]')
    ).toHaveLength(7);
    expect(wrapper.find('[data-testid="kanban"]').exists()).toBe(true);
    expect(wrapper.find('[data-testid="history"]').exists()).toBe(true);
  });

  // 123jpnbcb54: os atributos ficam escondidos até alguém os abrir, como no Kommo.
  it('keeps the attributes closed until someone opens them', async () => {
    const wrapper = mountComponent();

    expect(wrapper.find('[data-testid="attributes"]').exists()).toBe(false);

    await wrapper
      .find('[data-testid="raevo-contact-section-attributes"] button')
      .trigger('click');

    expect(mockDispatch).toHaveBeenCalledWith('updateUISettings', {
      uiSettings: expect.objectContaining({
        raevo_contact_sections: expect.objectContaining({ attributes: true }),
      }),
    });
  });

  it('remembers what each person opened', () => {
    mockUISettings = {
      raevo_contact_sections: { attributes: true, kanban: false },
    };

    const wrapper = mountComponent();

    expect(wrapper.find('[data-testid="attributes"]').exists()).toBe(true);
    expect(wrapper.find('[data-testid="kanban"]').exists()).toBe(false);
  });
});
