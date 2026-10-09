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

  // Decisão de 09/10: a lista fica com a conversa aberta, a qualquer largura.
  // Escondê-la (16/09) obrigava a voltar atrás para abrir a conversa seguinte.
  it('keeps the conversation list while a conversation is open on a narrow screen', () => {
    const wrapper = mountView();

    expect(wrapper.vm.showConversationList).toBe(true);
    expect(
      wrapper.findComponent({ name: 'ChatList' }).props('isOnExpandedLayout')
    ).toBe(false);
  });

  it('keeps the list when no conversation is open, whatever the width', () => {
    const wrapper = mountView({ conversationId: 0 });

    expect(wrapper.vm.showConversationList).toBe(true);
  });

  // O espaço vem da navegação: recolhe a ícones (56px) com a conversa aberta.
  // A 1536px — 1920 com zoom de 125% — a conversa ficava com 504px.
  it('collapses the navigation to icons while a conversation is open below 1600px', async () => {
    larguraDaJanela.value = 1536;
    const wrapper = mountView();
    await wrapper.vm.$nextTick();

    expect(definirFoco).toHaveBeenLastCalledWith(true);

    larguraDaJanela.value = 1600;
    await wrapper.vm.$nextTick();

    expect(definirFoco).toHaveBeenLastCalledWith(false);
  });

  // Recolher não é esconder, e só vale enquanto há conversa: na lista sozinha a
  // navegação fica com a largura que a pessoa escolheu.
  it('leaves the navigation alone when no conversation is open', async () => {
    const wrapper = mountView({ conversationId: 0 });
    await wrapper.vm.$nextTick();

    expect(definirFoco).toHaveBeenLastCalledWith(false);
  });
});
