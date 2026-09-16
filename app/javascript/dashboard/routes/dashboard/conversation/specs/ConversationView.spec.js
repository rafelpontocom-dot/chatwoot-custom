import { shallowMount } from '@vue/test-utils';
import { ref } from 'vue';
import ConversationView from '../ConversationView.vue';

const larguraDaJanela = ref(1280);
const definirFoco = vi.fn();

vi.mock('@vueuse/core', async () => {
  const actual = await vi.importActual('@vueuse/core');
  return { ...actual, useWindowSize: () => ({ width: larguraDaJanela }) };
});

vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({
    uiSettings: ref({ conversation_display_type: 'condensed' }),
    updateUISettings: vi.fn(),
  }),
}));

vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({ accountId: ref(8) }),
}));

vi.mock('dashboard/composables/useSidebarFocus', () => ({
  useRequestSidebarFocus: () => ({ setSidebarFocus: definirFoco }),
}));

const mountView = (props = {}) =>
  shallowMount(ConversationView, {
    props: { conversationId: 55, ...props },
    global: {
      stubs: {
        ChatList: true,
        ConversationBox: { template: '<div><slot /></div>' },
        ConversationSidebar: true,
        CmdBarConversationSnooze: true,
        SidepanelSwitch: true,
      },
      mocks: {
        $store: {
          dispatch: vi.fn(),
          getters: {
            getSelectedChat: { id: 55 },
            getAllConversations: [],
          },
        },
        $route: { params: {}, query: {} },
      },
    },
  });

describe('ConversationView', () => {
  beforeEach(() => {
    larguraDaJanela.value = 1280;
    definirFoco.mockClear();
  });

  // A 1280px a conversa ficava com 380px: navegação, lista e oportunidade
  // comiam o resto. Com a conversa aberta, a lista sai da frente.
  it('hides the conversation list while a conversation is open on a narrow screen', () => {
    const wrapper = mountView();

    expect(wrapper.vm.showConversationList).toBe(false);
    expect(wrapper.vm.isCompactWorkspace).toBe(true);
  });

  it('keeps the list when there is room for everything', () => {
    larguraDaJanela.value = 1600;
    const wrapper = mountView();

    expect(wrapper.vm.showConversationList).toBe(true);
    expect(wrapper.vm.isCompactWorkspace).toBe(false);
  });

  it('keeps the list when no conversation is open, whatever the width', () => {
    const wrapper = mountView({ conversationId: 0 });

    expect(wrapper.vm.showConversationList).toBe(true);
  });

  // Recolher não é esconder: os módulos continuam à distância de um clique, e a
  // largura que a pessoa escolheu para a barra não é gravada por cima.
  it('collapses the navigation to icons only while the workspace is compact', async () => {
    const wrapper = mountView();
    await wrapper.vm.$nextTick();

    expect(definirFoco).toHaveBeenLastCalledWith(true);

    larguraDaJanela.value = 1600;
    await wrapper.vm.$nextTick();

    expect(definirFoco).toHaveBeenLastCalledWith(false);
  });
});
