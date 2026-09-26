import { flushPromises, shallowMount } from '@vue/test-utils';
import KanbanFunnelView from '../KanbanFunnelView.vue';
import KanbanBoardsAPI from 'dashboard/api/kanbanBoards';

const mockPush = vi.fn();

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '1', boardId: '10' } }),
  useRouter: () => ({ push: mockPush }),
}));

vi.mock('dashboard/api/kanbanBoards', () => ({
  default: {
    getBoardFunnel: vi.fn(),
    showBoard: vi.fn(),
  },
}));

const etapa = (extra = {}) => ({
  id: 1,
  name: 'Novo contacto',
  category: 'open',
  entered: 10,
  advanced: 6,
  conversion: 60.0,
  lost: 2,
  open: 3,
  ...extra,
});

// O servidor responde em snake_case; a tela camelcasa. O mock devolve snake_case
// de propósito, senão o teste não exercita essa conversão.
const montar = async ({ stages = [etapa()], windowDays = 30 } = {}) => {
  KanbanBoardsAPI.getBoardFunnel.mockResolvedValue({
    data: { window_days: windowDays, stages },
  });
  KanbanBoardsAPI.showBoard.mockResolvedValue({ data: { name: 'Comercial' } });

  const wrapper = shallowMount(KanbanFunnelView, {
    global: {
      stubs: {
        RaevoPageHeader: {
          template: '<header><slot name="actions" /><slot /></header>',
        },
      },
    },
  });
  await flushPromises();
  return wrapper;
};

describe('KanbanFunnelView', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders one row per stage with the four counts side by side', async () => {
    const wrapper = await montar();
    const celulas = wrapper.findAll('tbody tr td').map(td => td.text());

    expect(wrapper.findAll('tbody tr')).toHaveLength(1);
    expect(wrapper.find('tbody th').text()).toContain('Novo contacto');
    // entraram · avançaram · conversão · perdidas · abertas
    expect(celulas[0]).toBe('10');
    expect(celulas[1]).toBe('6');
    expect(celulas[2]).toContain('60%');
    expect(celulas[3]).toBe('2');
    expect(celulas[4]).toBe('3');
  });

  // A regra que atravessa o produto: onde não há base para o número, travessão e
  // não zero. Zero por cento diria que ninguém avançou.
  it('shows a dash instead of zero per cent for a stage nobody reached', async () => {
    const wrapper = await montar({
      stages: [
        etapa(),
        etapa({
          id: 2,
          name: 'Proposta',
          entered: 0,
          advanced: 0,
          conversion: null,
        }),
      ],
    });
    const conversoes = wrapper
      .findAll('tbody tr')
      .map(linha => linha.findAll('td')[2].text());

    expect(conversoes[0]).toContain('60%');
    expect(conversoes[1]).toContain('—');
  });

  it('shows the empty state when nothing moved in the window', async () => {
    const wrapper = await montar({
      stages: [etapa({ entered: 0, advanced: 0, conversion: null })],
    });

    expect(wrapper.find('[data-testid="kanban-funnel-empty"]').exists()).toBe(
      true
    );
    expect(wrapper.find('tbody').exists()).toBe(false);
  });

  it('says so when the board has no stages, instead of showing an empty table', async () => {
    const wrapper = await montar({ stages: [] });

    expect(
      wrapper.find('[data-testid="kanban-funnel-no-stages"]').exists()
    ).toBe(true);
  });

  it('offers a retry when the funnel could not be read', async () => {
    KanbanBoardsAPI.getBoardFunnel.mockRejectedValueOnce(new Error('boom'));
    KanbanBoardsAPI.showBoard.mockResolvedValue({
      data: { name: 'Comercial' },
    });

    const wrapper = shallowMount(KanbanFunnelView, {
      global: {
        stubs: {
          RaevoPageHeader: {
            template: '<header><slot name="actions" /><slot /></header>',
          },
        },
      },
    });
    await flushPromises();

    expect(wrapper.text()).toContain('KANBAN.FUNNEL.ERROR');

    KanbanBoardsAPI.getBoardFunnel.mockResolvedValue({
      data: { window_days: 30, stages: [etapa()] },
    });
    await wrapper.find('[data-testid="kanban-funnel-retry"]').trigger('click');
    await flushPromises();

    expect(wrapper.findAll('tbody tr')).toHaveLength(1);
  });

  it('goes back to the board without a full page load', async () => {
    const wrapper = await montar();
    await wrapper.find('[data-testid="kanban-funnel-back"]').trigger('click');

    expect(mockPush).toHaveBeenCalledWith({
      name: 'kanban_board_show',
      params: { accountId: '1', boardId: 10 },
    });
  });
});
