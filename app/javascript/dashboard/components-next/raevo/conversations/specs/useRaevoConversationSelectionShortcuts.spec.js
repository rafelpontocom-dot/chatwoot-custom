import { mount } from '@vue/test-utils';
import { defineComponent, h, nextTick, ref } from 'vue';
import { useRaevoConversationSelectionShortcuts } from '../useRaevoConversationSelectionShortcuts';

let atalhos = {};
const rota = { params: { conversation_id: '12' } };
vi.mock('vue-router', () => ({ useRoute: () => rota }));
vi.mock('dashboard/composables/useKeyboardEvents', () => ({
  useKeyboardEvents: eventos => {
    atalhos = eventos;
  },
}));

const conversas = [11, 12, 13, 14, 15].map(id => ({ id, inbox_id: 1 }));

const montar = () => {
  const selecionadas = ref([]);
  const menuAberto = ref(false);
  const limpar = vi.fn();
  const selecionar = vi.fn(id => {
    selecionadas.value = [...selecionadas.value, id];
  });
  const desmarcar = vi.fn(id => {
    selecionadas.value = selecionadas.value.filter(x => x !== id);
  });
  const Sonda = defineComponent({
    setup() {
      useRaevoConversationSelectionShortcuts({
        conversationList: ref(conversas),
        selectedConversations: selecionadas,
        clear: limpar,
        isMenuOpen: menuAberto,
      });
      return () => h('div');
    },
  });
  mount(Sonda, {
    attachTo: document.body,
    global: {
      provide: {
        selectConversation: selecionar,
        deSelectConversation: desmarcar,
      },
    },
  });
  return { selecionadas, menuAberto, limpar, selecionar, desmarcar };
};

describe('useRaevoConversationSelectionShortcuts (123jpnbcxh4)', () => {
  it('marks and unmarks the open conversation with X', () => {
    const { selecionadas, selecionar, desmarcar } = montar();

    atalhos.KeyX.action();
    expect(selecionar).toHaveBeenCalledWith(12, 1);
    expect(selecionadas.value).toEqual([12]);

    atalhos.KeyX.action();
    expect(desmarcar).toHaveBeenCalledWith(12, 1);
  });

  it('marks the whole range with Shift+click, in list order', async () => {
    const { selecionadas } = montar();

    selecionadas.value = [11];
    await nextTick();
    document.dispatchEvent(new MouseEvent('mousedown', { shiftKey: true }));
    selecionadas.value = [11, 14];
    await nextTick();

    expect([...selecionadas.value].sort()).toEqual([11, 12, 13, 14]);
  });

  // Abrir uma conversa põe o foco no editor, onde «x» é texto.
  it('marks the open conversation with Alt+X, even from the reply editor', () => {
    const { selecionar } = montar();
    const evento = { preventDefault: vi.fn() };

    expect(atalhos['Alt+KeyX'].allowOnFocusedInput).toBe(true);
    atalhos['Alt+KeyX'].action(evento);

    expect(evento.preventDefault).toHaveBeenCalled();
    expect(selecionar).toHaveBeenCalledWith(12, 1);
  });

  it('clears with Esc from the photo checkbox, but not while writing', () => {
    const { selecionadas, limpar } = montar();
    selecionadas.value = [11];
    const caixa = document.createElement('input');
    caixa.type = 'checkbox';
    document.body.appendChild(caixa);
    caixa.focus();
    atalhos.Escape.action();
    expect(limpar).toHaveBeenCalledTimes(1);

    const texto = document.createElement('textarea');
    document.body.appendChild(texto);
    texto.focus();
    atalhos.Escape.action();
    expect(limpar).toHaveBeenCalledTimes(1);
    caixa.remove();
    texto.remove();
  });

  it('clears with Esc, but not while a menu is open', () => {
    const { selecionadas, menuAberto, limpar } = montar();
    selecionadas.value = [11];

    menuAberto.value = true;
    atalhos.Escape.action();
    expect(limpar).not.toHaveBeenCalled();

    menuAberto.value = false;
    atalhos.Escape.action();
    expect(limpar).toHaveBeenCalled();
  });
});
