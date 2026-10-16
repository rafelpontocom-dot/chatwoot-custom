import { shallowMount, flushPromises } from '@vue/test-utils';
import { ref } from 'vue';
import InboxView from '../InboxView.vue';

vi.mock('vue-router', async importOriginal => ({
  ...(await importOriginal()),
  useRoute: () => ({ params: { inboxId: 1, id: 55 } }),
  useRouter: () => ({ push: vi.fn() }),
}));

const conversa = { id: 55, inbox_id: 1 };
const getters = {
  'notifications/getFilteredNotifications': () => [
    { id: 1, primary_actor: { id: 55 } },
  ],
  getSelectedChat: conversa,
  getConversationById: () => conversa,
  'notifications/getUIFlags': { isFetching: false },
  'notifications/getMeta': { count: 1 },
};

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch: vi.fn() }),
  useMapGetter: name => ref(getters[name]),
}));
vi.mock('dashboard/composables', () => ({ useTrack: vi.fn() }));
vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({ uiSettings: ref({}) }),
}));

// 123jpnbd3by: o botão do contacto mora no cabeçalho da conversa, que a caixa
// de entrada também mostra. O ícone flutuante nativo ficava em duplicado.
describe('InboxView', () => {
  it('does not float the side panel switch over the conversation', async () => {
    const wrapper = shallowMount(InboxView, {
      global: {
        stubs: { ConversationBox: { template: '<div><slot /></div>' } },
        mocks: { $t: key => key },
      },
    });
    await flushPromises();

    expect(wrapper.find('[is-inbox-view]').exists()).toBe(true);
    expect(wrapper.html()).not.toContain('sidepanel-switch');
  });
});
