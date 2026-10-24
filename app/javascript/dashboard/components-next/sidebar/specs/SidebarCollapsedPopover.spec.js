import { mount } from '@vue/test-utils';
import { ref } from 'vue';
import SidebarCollapsedPopover from '../SidebarCollapsedPopover.vue';

const sidebarWidth = ref(56);

vi.mock('../provider', () => ({
  useSidebarContext: () => ({
    isAllowed: () => true,
    sidebarWidth,
  }),
  usePopoverState: () => ({
    activePopover: ref(null),
    setActivePopover: vi.fn(),
    closeActivePopover: vi.fn(),
    scheduleClose: vi.fn(),
    cancelClose: vi.fn(),
  }),
}));

vi.mock('dashboard/composables/store', async () => {
  const { computed } = await vi.importActual('vue');

  return { useMapGetter: () => computed(() => false) };
});

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const montar = () =>
  mount(SidebarCollapsedPopover, {
    props: { label: 'Conversas', children: [], triggerRect: { top: 120 } },
    global: {
      stubs: {
        TeleportWithDirection: { template: '<div><slot /></div>' },
        RouterLink: true,
      },
    },
  });

describe('SidebarCollapsedPopover', () => {
  // O popover posiciona-se em «largura da barra + 8». Com a barra recolhida por
  // foco — que é o que acontece ao abrir uma conversa — a largura GRAVADA
  // continuava a ser a expandida, e o menu abria a 240px da esquerda, por cima
  // da lista de conversas. Daí o defeito só aparecer com as conversas abertas.
  it('opens beside the rail, at the width the sidebar actually has', () => {
    sidebarWidth.value = 56;

    const painel = montar().find('[style]');

    expect(painel.attributes('style')).toContain('left: 64px');
  });

  it('follows the rail when it widens', () => {
    sidebarWidth.value = 240;

    const painel = montar().find('[style]');

    expect(painel.attributes('style')).toContain('left: 248px');
  });
});
