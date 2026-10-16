import { shallowMount, flushPromises } from '@vue/test-utils';
import { ref } from 'vue';
import ChatList from '../ChatList.vue';

// Contrato de upgrade `conversation-list-preferences`: as costuras do Raevo
// dentro do ChatList nativo. Se um upgrade do Chatwoot as levar, estes testes
// falham — foi verificado pondo a versão oficial do ficheiro no lugar.

const preferencias = ref({});
const gravarPreferencias = vi.fn();
const despachar = vi.fn(() => Promise.resolve());
const filtrosGuardados = ref([]);

vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({
    uiSettings: preferencias,
    updateUISettings: gravarPreferencias,
  }),
}));

vi.mock('vue-router', () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn() }),
  useRoute: () => ({ name: 'home', params: { accountId: 1 }, query: {} }),
}));

const fn = () => () => ({});
const getters = {
  'agents/getAgents': [],
  'attributes/getAttributesByModel': () => [],
  'bulkActions/getSelectedConversationIds': [],
  'conversationPage/getCurrentPageFilter': () => 0,
  'conversationPage/getHasEndReached': () => false,
  'campaigns/getAllCampaigns': [],
  'contacts/getContact': () => ({}),
  'conversationStats/getStats': {},
  'customViews/getActiveFolderContactId': null,
  getAllStatusChats: () => [],
  getAppliedContactFilter: null,
  getAppliedConversationFiltersQuery: {},
  getAppliedConversationFiltersV2: [],
  getChatListLoadingStatus: false,
  getConversationById: fn(),
  getCurrentAccountId: 1,
  getCurrentUser: {
    id: 1,
    accounts: [
      { id: 1, role: 'administrator', permissions: ['administrator'] },
    ],
  },
  getFilteredConversations: [],
  getMineChats: () => [],
  getParticipatingChats: () => [],
  getSelectedInbox: null,
  getUnAssignedChats: () => [],
  'inboxes/getInbox': fn(),
  'inboxes/getInboxes': [],
  'labels/getLabels': [],
  'teams/getTeam': fn(),
  'teams/getTeams': [],
};
// O mesmo store pelos dois caminhos: o `useStore` do vuex e o `$store` da
// instância, que é o que o `useMapGetter` do Chatwoot lê.
const loja = {
  getters: new Proxy(getters, {
    get: (target, key) =>
      key === 'customViews/getConversationCustomViews'
        ? filtrosGuardados.value
        : target[key],
  }),
  dispatch: despachar,
  state: {},
};

vi.mock('vuex', async () => ({
  ...(await vi.importActual('vuex')),
  useStore: () => loja,
}));

const montar = (props = {}) =>
  shallowMount(ChatList, {
    props,
    global: {
      stubs: { TeleportWithDirection: true },
      // `mocks` só chega depois do setup; o `useMapGetter` lê o store dentro dele.
      config: { globalProperties: { $store: loja } },
    },
  });

describe('ChatList — o que o Raevo acrescenta à lista nativa', () => {
  beforeEach(() => {
    preferencias.value = {};
    filtrosGuardados.value = [];
  });

  it('opens on the tab the agent chose, over the last one used', async () => {
    preferencias.value = {
      conversations_default_assignee_tab: 'unassigned',
      conversations_filter_by: { assignee_tab: 'all' },
    };
    const wrapper = montar();
    await flushPromises();

    expect(
      wrapper.findComponent({ name: 'ChatTypeTabs' }).props('activeTab')
    ).toBe('unassigned');
  });

  it('remembers the tab the agent switches to', async () => {
    preferencias.value = { conversations_filter_by: { status: 'open' } };
    const wrapper = montar();
    await flushPromises();

    wrapper
      .findComponent({ name: 'ChatTypeTabs' })
      .vm.$emit('chatTabChange', 'all');

    expect(gravarPreferencias).toHaveBeenCalledWith({
      conversations_filter_by: { status: 'open', assignee_tab: 'all' },
    });
  });

  it('pins the open saved filter as the one the panel opens with, and unpins it', async () => {
    filtrosGuardados.value = [
      { id: 7, name: 'Retornos', query: { payload: [] } },
    ];
    const wrapper = montar({ foldersId: 7 });
    await flushPromises();
    const cabecalho = wrapper.findComponent({ name: 'ChatListHeader' });

    expect(cabecalho.props('isDefaultFolder')).toBe(false);
    cabecalho.vm.$emit('toggleDefaultFolder');
    expect(gravarPreferencias).toHaveBeenLastCalledWith({
      conversations_default_folder_id: 7,
    });

    preferencias.value = { conversations_default_folder_id: 7 };
    await flushPromises();
    expect(cabecalho.props('isDefaultFolder')).toBe(true);
    cabecalho.vm.$emit('toggleDefaultFolder');
    expect(gravarPreferencias).toHaveBeenLastCalledWith({
      conversations_default_folder_id: null,
    });
  });
});
