import { shallowMount } from '@vue/test-utils';
import ChatListHeader from '../ChatListHeader.vue';

vi.mock('dashboard/composables/useUISettings', async () => {
  const { ref } = await import('vue');
  return {
    useUISettings: () => ({
      uiSettings: ref({}),
      updateUISettings: vi.fn(),
    }),
  };
});

const mountHeader = props =>
  shallowMount(ChatListHeader, {
    props: {
      pageTitle: 'Conversations',
      hasAppliedFilters: false,
      hasActiveFolders: false,
      activeStatus: 'open',
      isOnExpandedLayout: false,
      conversationStats: { allCount: 12 },
      isListLoading: false,
      ...props,
    },
    global: {
      mocks: { $t: key => key },
      stubs: {
        RouterLink: {
          name: 'RouterLink',
          props: ['to'],
          template: '<a><slot /></a>',
        },
      },
    },
  });

const contactFilter = { id: 7, name: 'Jane Doe' };

describe('ChatListHeader', () => {
  // 24/10, 123jpnbd8y6: a busca passou a viver na própria lista, no lugar de
  // «Selecionar todas». A lupa daqui era a segunda entrada de pesquisa no
  // mesmo cabeçalho, e saiu por decisão do Pedro. A tela completa continua
  // acessível pela pesquisa da navegação lateral.
  it('no longer carries a second search entry in the header', () => {
    const wrapper = mountHeader();

    expect(wrapper.find('[data-testid="conversation-search"]').exists()).toBe(
      false
    );
  });
  it('renders the page title and the filter button without filters', () => {
    const wrapper = mountHeader();

    expect(wrapper.find('h1').text()).toBe('Conversations');
    expect(wrapper.find('#toggleConversationFilterButton').exists()).toBe(true);
    expect(wrapper.find('[icon="i-lucide-chevron-left"]').exists()).toBe(false);
  });

  it('keeps the page title and the filter button for non contact filters', () => {
    const wrapper = mountHeader({ hasAppliedFilters: true });

    expect(wrapper.find('h1').text()).toBe('Conversations');
    expect(wrapper.find('#toggleConversationFilterButton').exists()).toBe(true);
    expect(wrapper.find('[icon="i-lucide-chevron-left"]').exists()).toBe(true);
  });

  it('names the contact and hides the filter button when scoped to a contact', () => {
    const wrapper = mountHeader({ hasAppliedFilters: true, contactFilter });

    expect(wrapper.find('h1').text()).toBe('Jane Doe');
    expect(wrapper.find('#toggleConversationFilterButton').exists()).toBe(
      false
    );
    expect(wrapper.find('[icon="i-lucide-chevron-left"]').exists()).toBe(true);
  });

  it('falls back to the page title when the scoped contact has no name', () => {
    const wrapper = mountHeader({
      hasAppliedFilters: true,
      contactFilter: { id: 7, name: '' },
    });

    expect(wrapper.find('h1').text()).toBe('Conversations');
    expect(wrapper.find('#toggleConversationFilterButton').exists()).toBe(
      false
    );
  });

  it('keeps the folder controls when a folder is active', () => {
    const wrapper = mountHeader({
      hasAppliedFilters: true,
      hasActiveFolders: true,
      contactFilter,
    });

    expect(wrapper.find('h1').text()).toBe('Conversations');
    expect(wrapper.find('[icon="i-lucide-pen-line"]').exists()).toBe(true);
    expect(wrapper.find('[icon="i-lucide-trash-2"]').exists()).toBe(true);
  });

  // Contrato `conversation-list-preferences`: fixar o filtro que abre o painel.
  it('pins and unpins the open folder as the one the panel opens with', async () => {
    const solto = mountHeader({
      hasAppliedFilters: true,
      hasActiveFolders: true,
    });
    const fixar = solto.find('[data-testid="toggle-default-folder"]');

    expect(fixar.attributes('icon')).toBe('i-lucide-pin');
    await fixar.trigger('click');
    expect(solto.emitted('toggleDefaultFolder')).toHaveLength(1);

    const fixado = mountHeader({
      hasAppliedFilters: true,
      hasActiveFolders: true,
      isDefaultFolder: true,
    });
    expect(
      fixado.find('[data-testid="toggle-default-folder"]').attributes('icon')
    ).toBe('i-lucide-pin-off');
  });
});
