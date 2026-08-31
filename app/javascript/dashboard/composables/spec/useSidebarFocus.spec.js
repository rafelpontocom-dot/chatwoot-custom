import { mount } from '@vue/test-utils';
import { defineComponent, h } from 'vue';

import { useRequestSidebarFocus, useSidebarFocus } from '../useSidebarFocus';

const Pedinte = defineComponent({
  setup(_, { expose }) {
    const { setSidebarFocus } = useRequestSidebarFocus();
    expose({ setSidebarFocus });
    return () => h('div');
  },
});

describe('useSidebarFocus', () => {
  const { isSidebarFocused } = useSidebarFocus();

  afterEach(() => {
    const wrapper = mount(Pedinte);
    wrapper.vm.setSidebarFocus(false);
    wrapper.unmount();
  });

  it('starts out of focus mode', () => {
    expect(isSidebarFocused.value).toBe(false);
  });

  it('shares the state between who asks and who reads', () => {
    const wrapper = mount(Pedinte);

    wrapper.vm.setSidebarFocus(true);

    expect(isSidebarFocused.value).toBe(true);
    wrapper.unmount();
  });

  it('gives the navigation back when the screen that asked goes away', () => {
    // Sair pelo botão «voltar», pelo menu ou pelo atalho do browser tem de
    // devolver a barra; confiar em cada saída lembrar-se disso não dura.
    const wrapper = mount(Pedinte);
    wrapper.vm.setSidebarFocus(true);

    wrapper.unmount();

    expect(isSidebarFocused.value).toBe(false);
  });

  it('does not let a reader change it', () => {
    // É leitura só: quem lê a barra não decide se ela recolhe. O Vue não
    // levanta nesta atribuição — avisa e ignora —, por isso o que se verifica
    // é que ela não pegou.
    const aviso = vi.spyOn(console, 'warn').mockImplementation(() => {});

    isSidebarFocused.value = true;

    expect(isSidebarFocused.value).toBe(false);
    aviso.mockRestore();
  });
});
