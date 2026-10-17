import { mount, flushPromises } from '@vue/test-utils';
import { ref } from 'vue';
import RaevoConversationBulkBar from '../RaevoConversationBulkBar.vue';
import BulkActionsAPI from 'dashboard/api/raevoConversationBulkActions';

const alerta = vi.fn();
const admin = ref(true);

vi.mock('dashboard/api/raevoConversationBulkActions', () => ({
  default: { count: vi.fn(), apply: vi.fn() },
}));
vi.mock('dashboard/composables', () => ({ useAlert: (...a) => alerta(...a) }));
vi.mock('dashboard/composables/useAdmin', () => ({
  useAdmin: () => ({ isAdmin: admin }),
}));
vi.mock('dashboard/composables/store', () => ({
  useMapGetter: name =>
    ref(
      {
        'labels/getLabels': [{ title: 'retorno' }, { title: 'vip' }],
        'agents/getAgents': [{ id: 7, name: 'Thiago' }],
        'teams/getTeams': [{ id: 2, name: 'Comercial' }],
        getCurrentAccountId: 1,
      }[name]
    ),
}));
vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => (params ? `${key}:${JSON.stringify(params)}` : key),
  }),
}));

const conversas = [{ id: 11 }, { id: 12 }, { id: 13 }];
const scope = { filters: { status: 'open' } };

const montar = (selectedConversations = []) =>
  mount(RaevoConversationBulkBar, {
    props: { conversationList: conversas, selectedConversations, scope },
    global: {
      stubs: {
        Dialog: {
          template: '<div data-testid="dialog">{{ title }}</div>',
          props: ['title'],
          emits: ['confirm'],
          methods: { open() {}, close() {} },
        },
      },
    },
  });

const clicar = (wrapper, testid) =>
  wrapper.get(`[data-testid="${testid}"]`).trigger('click');

describe('RaevoConversationBulkBar (123jpnbcxh4, proposta B)', () => {
  beforeEach(() => {
    admin.value = true;
    alerta.mockClear();
    BulkActionsAPI.apply.mockReset().mockResolvedValue({
      data: { count: 2, skipped: 0 },
    });
    BulkActionsAPI.count.mockReset().mockResolvedValue({ data: { count: 3 } });
  });

  it('shows «select all» on the first line before anything is selected', () => {
    const wrapper = montar();

    expect(wrapper.get('[data-testid="raevo-bulk-select-all"]').text()).toBe(
      'RAEVO_CONVERSATION.BULK.SELECT_ALL'
    );
    expect(wrapper.find('[data-testid="raevo-bulk-actions"]').exists()).toBe(
      false
    );
  });

  it('asks the list to select every loaded conversation', async () => {
    const wrapper = montar();
    await wrapper.get('input[type="checkbox"]').setValue(true);

    expect(wrapper.emitted('selectAllConversations')[0]).toEqual([true]);
  });

  it('resolves the marked conversations and says how many', async () => {
    const wrapper = montar([11, 12]);
    await clicar(wrapper, 'raevo-bulk-resolve');
    await flushPromises();

    expect(BulkActionsAPI.apply).toHaveBeenCalledWith({
      scope: { ids: [11, 12] },
      operation: 'resolve',
      value: null,
    });
    expect(alerta).toHaveBeenCalledWith(
      expect.stringContaining('RAEVO_CONVERSATION.BULK.DONE')
    );
    expect(wrapper.emitted('clear')).toBeTruthy();
  });

  it('keeps Resolve, Snooze and Pending in sight, the rest under More', async () => {
    const wrapper = montar([11]);
    ['resolve', 'snooze', 'pending', 'more'].forEach(chave =>
      expect(wrapper.find(`[data-testid="raevo-bulk-${chave}"]`).exists()).toBe(
        true
      )
    );

    await clicar(wrapper, 'raevo-bulk-more');
    expect(
      wrapper.find('[data-testid="raevo-bulk-item-priority"]').exists()
    ).toBe(true);
    expect(
      wrapper.find('[data-testid="raevo-bulk-item-unread"]').exists()
    ).toBe(true);
  });

  it('offers the whole filter once the page is selected, and confirms first', async () => {
    const wrapper = montar([11, 12, 13]);
    BulkActionsAPI.count.mockResolvedValue({ data: { count: 312 } });
    await wrapper.setProps({ selectedConversations: [11, 12] });
    await wrapper.setProps({ selectedConversations: [11, 12, 13] });
    await flushPromises();

    await clicar(wrapper, 'raevo-bulk-select-filter');
    expect(
      wrapper.get('[data-testid="raevo-bulk-select-all"]').text()
    ).toContain('312');

    await clicar(wrapper, 'raevo-bulk-pending');
    expect(BulkActionsAPI.apply).not.toHaveBeenCalled();
    expect(wrapper.get('[data-testid="dialog"]').text()).toContain('312');

    wrapper.findComponent('[data-testid="dialog"]').vm.$emit('confirm');
    await flushPromises();
    expect(BulkActionsAPI.apply).toHaveBeenCalledWith({
      scope,
      operation: 'pending',
      value: null,
    });
  });

  it('applies a picked priority, label, agent or team', async () => {
    const wrapper = montar([11]);
    await clicar(wrapper, 'raevo-bulk-more');
    await clicar(wrapper, 'raevo-bulk-item-add_labels');
    await clicar(wrapper, 'raevo-bulk-pick-vip');
    await flushPromises();

    expect(BulkActionsAPI.apply).toHaveBeenCalledWith({
      scope: { ids: [11] },
      operation: 'add_labels',
      value: ['vip'],
    });
  });

  it('snoozes with the native snooze times', async () => {
    const wrapper = montar([11]);
    await clicar(wrapper, 'raevo-bulk-snooze');
    const [primeira] = wrapper.findAll(
      '[data-testid="raevo-bulk-menu"] button'
    );
    await primeira.trigger('click');
    await flushPromises();

    expect(BulkActionsAPI.apply).toHaveBeenCalledWith(
      expect.objectContaining({ operation: 'snooze' })
    );
  });

  it('allows open in new tab and copy link with one conversation only', async () => {
    const wrapper = montar([11, 12]);
    await clicar(wrapper, 'raevo-bulk-more');

    expect(
      wrapper
        .get('[data-testid="raevo-bulk-item-open_tab"]')
        .attributes('disabled')
    ).toBeDefined();
  });

  // Decisão de 17/10: excluir em lote só para administradores, e sempre com confirmação.
  it('offers delete to administrators only, always behind a confirmation', async () => {
    admin.value = false;
    const agente = montar([11]);
    await clicar(agente, 'raevo-bulk-more');
    expect(agente.find('[data-testid="raevo-bulk-item-delete"]').exists()).toBe(
      false
    );

    admin.value = true;
    const administrador = montar([11]);
    await clicar(administrador, 'raevo-bulk-more');
    await clicar(administrador, 'raevo-bulk-item-delete');
    expect(BulkActionsAPI.apply).not.toHaveBeenCalled();
    expect(administrador.get('[data-testid="dialog"]').text()).toContain(
      'CONFIRM_DELETE_TITLE'
    );
  });
});
