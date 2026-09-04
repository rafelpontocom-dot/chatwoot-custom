import { shallowMount, flushPromises } from '@vue/test-utils';
import { computed } from 'vue';
import MarketingView from '../MarketingView.vue';

const apiMocks = vi.hoisted(() => ({
  getModule: vi.fn(),
  updateModule: vi.fn(),
  getTouchpoints: vi.fn(),
  getSummary: vi.fn(),
  getIntakeSources: vi.fn(),
  createIntakeSource: vi.fn(),
  rotateIntakeSource: vi.fn(),
  deactivateIntakeSource: vi.fn(),
  getConnections: vi.fn(),
  connectionAuthorizationUrl: vi.fn(),
  disconnect: vi.fn(),
  syncPages: vi.fn(),
  subscribePage: vi.fn(),
  syncLeadForms: vi.fn(),
  connectionPermissions: vi.fn(),
  getLeadForms: vi.fn(),
  updateLeadForm: vi.fn(),
}));
const boardsMocks = vi.hoisted(() => ({ get: vi.fn(), getSettings: vi.fn() }));
const storeMocks = vi.hoisted(() => ({
  currentAccount: { id: 7, permissions: ['administrator'] },
  inboxes: [{ id: 3, name: 'WhatsApp' }],
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key, locale: { value: 'pt_BR' } }),
}));
vi.mock('dashboard/api/marketing', () => ({ default: apiMocks }));
vi.mock('dashboard/api/kanbanBoards', () => ({ default: boardsMocks }));
vi.mock('dashboard/composables/store', () => ({
  useMapGetter: key =>
    computed(() =>
      key === 'inboxes/getInboxes'
        ? storeMocks.inboxes
        : storeMocks.currentAccount
    ),
}));

// `shallowMount` stuba os filhos e o conteúdo dos slots some — inclusive o
// botão da engrenagem, que vive no slot `actions` do RaevoPageHeader.
const stubs = {
  RaevoPageHeader: {
    template: '<header><slot name="actions" /><slot /></header>',
  },
  // o stub tem de mostrar o rótulo, senão o texto do selo some do teste
  RaevoStamp: { props: ['label'], template: '<span>{{ label }}</span>' },
  RaevoField: {
    template:
      '<label><slot :control-class="\'c\'" :field-id="\'f\'" /></label>',
  },
  NextButton: { template: '<button />' },
  'router-link': { template: '<a><slot /></a>' },
};

const montar = () => shallowMount(MarketingView, { global: { stubs } });

describe('MarketingView', () => {
  beforeEach(() => {
    storeMocks.currentAccount = { id: 7, permissions: ['administrator'] };
    apiMocks.getModule.mockResolvedValue({ data: { enabled: true } });
    apiMocks.getIntakeSources.mockResolvedValue({ data: { payload: [] } });
    apiMocks.getConnections.mockResolvedValue({ data: { payload: [] } });
    apiMocks.getLeadForms.mockResolvedValue({ data: { payload: [] } });
    boardsMocks.get.mockResolvedValue({
      data: { payload: [{ id: 1, name: 'Funil' }] },
    });
    boardsMocks.getSettings.mockResolvedValue({
      data: { stages: [{ id: 5, name: 'Novo' }], allowed_inbox_ids: [3] },
    });
    apiMocks.getSummary.mockResolvedValue({
      data: {
        total: 4,
        identified: 3,
        capture_rate: 75.0,
        by_origin: { 'Mídia Paga': 3, Orgânico: 1 },
        top_campaigns: { fue: 2 },
      },
    });
    apiMocks.getTouchpoints.mockResolvedValue({
      data: {
        payload: [
          {
            id: 1,
            source: 'widget_referer',
            occurred_at: '2026-09-03T10:00:00Z',
            payload: { origem_do_lead: 'Mídia Paga', utm_campaign: 'fue' },
            contact: { id: 9, name: 'Maria' },
          },
        ],
      },
    });
  });

  it('leads with the capture rate, which says whether we are learning anything', async () => {
    const wrapper = montar();
    await flushPromises();

    expect(wrapper.find('[data-testid="marketing-capture-rate"]').text()).toBe(
      '75%'
    );
  });

  it('lists the leads with their origin and campaign', async () => {
    const wrapper = montar();
    await flushPromises();

    const table = wrapper.find('[data-testid="marketing-touchpoints-table"]');
    expect(table.exists()).toBe(true);
    expect(table.text()).toContain('Mídia Paga');
    expect(table.text()).toContain('Maria');
  });

  it('offers a way forward instead of an empty screen when the module is off', async () => {
    apiMocks.getModule.mockResolvedValue({ data: { enabled: false } });

    const wrapper = montar();
    await flushPromises();

    expect(wrapper.text()).toContain('MARKETING.EMPTY.DISABLED_TITLE');
    expect(apiMocks.getSummary).not.toHaveBeenCalled();
  });

  it('hides the settings gear from someone who cannot configure', async () => {
    storeMocks.currentAccount = { id: 7, permissions: ['agent'] };

    const wrapper = montar();
    await flushPromises();

    expect(
      wrapper.find('[data-testid="marketing-toggle-settings"]').exists()
    ).toBe(false);
  });

  it('asks for confirmation when turning the module off', async () => {
    apiMocks.updateModule.mockResolvedValue({ data: { enabled: false } });
    const wrapper = montar();
    await flushPromises();

    await wrapper
      .find('[data-testid="marketing-toggle-settings"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="marketing-toggle-module"]')
      .setValue(false);

    expect(apiMocks.updateModule).toHaveBeenCalledWith({
      marketing_module: { enabled: false, confirm_disable: true },
    });
  });

  it('says so when the data cannot be loaded', async () => {
    apiMocks.getModule.mockRejectedValue({
      response: { data: { message: 'boom' } },
    });

    const wrapper = montar();
    await flushPromises();

    expect(wrapper.text()).toContain('boom');
  });

  it('offers Meta and marks the other platforms as not ready yet', async () => {
    const wrapper = montar();
    await flushPromises();
    await wrapper
      .find('[data-testid="marketing-toggle-settings"]')
      .trigger('click');

    expect(
      wrapper.find('[data-testid="marketing-connect-meta"]').exists()
    ).toBe(true);
    expect(wrapper.text()).toContain('Google Ads');
    expect(wrapper.text()).toContain('MARKETING.CONNECTIONS.SOON');
  });

  it('warns while there is still time to reconnect', async () => {
    apiMocks.getConnections.mockResolvedValue({
      data: {
        payload: [
          {
            id: 1,
            provider: 'meta',
            status: 'connected',
            display_name: 'Clinica',
            token_expiring: true,
            pages: [],
          },
        ],
      },
    });

    const wrapper = montar();
    await flushPromises();
    await wrapper
      .find('[data-testid="marketing-toggle-settings"]')
      .trigger('click');

    expect(wrapper.text()).toContain('MARKETING.CONNECTIONS.EXPIRING');
  });

  it('turns a refusal from Meta into a sentence rather than a silence', async () => {
    apiMocks.connectionAuthorizationUrl.mockRejectedValue({
      response: { data: { message: 'Meta Lead Ads app is not configured' } },
    });

    const wrapper = montar();
    await flushPromises();
    await wrapper
      .find('[data-testid="marketing-toggle-settings"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="marketing-connect-meta"]')
      .trigger('click');
    await flushPromises();

    expect(wrapper.text()).toContain('Meta Lead Ads app is not configured');
  });

  // "OAuthException (200)" não diz o que fazer; o motivo, sim.
  it('explains a permission refusal instead of echoing the Meta code', async () => {
    apiMocks.connectionAuthorizationUrl.mockRejectedValue({
      response: {
        data: {
          message: 'Meta responded 403: OAuthException (200)',
          error_code: 'permission',
        },
      },
    });

    const wrapper = montar();
    await flushPromises();
    await wrapper
      .find('[data-testid="marketing-toggle-settings"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="marketing-connect-meta"]')
      .trigger('click');
    await flushPromises();

    expect(wrapper.text()).toContain('MARKETING.CONNECTIONS.ERRORS.PERMISSION');
    expect(wrapper.text()).not.toContain('OAuthException');
  });

  // O Meta diz, por página, o que a conta pode fazer nela: avisar antes vale
  // mais do que deixar o clique falhar.
  it('flags a page the connected account does not fully control', async () => {
    apiMocks.getConnections.mockResolvedValue({
      data: {
        payload: [
          {
            id: 1,
            provider: 'meta',
            status: 'connected',
            display_name: 'Pedro Raphael',
            pages: [
              { id: '10', name: 'Clinica', tasks: ['ADVERTISE', 'ANALYZE'] },
              { id: '11', name: 'Outra', tasks: ['ADVERTISE', 'MANAGE'] },
            ],
          },
        ],
      },
    });

    const wrapper = montar();
    await flushPromises();
    await wrapper
      .find('[data-testid="marketing-toggle-settings"]')
      .trigger('click');

    expect(wrapper.text()).toContain('MARKETING.CONNECTIONS.PAGE_LIMITED');
    expect(
      wrapper.text().match(/MARKETING\.CONNECTIONS\.PAGE_LIMITED_HINT/g)
    ).toHaveLength(1);
  });

  // Com o papel na página já correto, é esta a resposta que resta.
  it('names the permission Meta withheld', async () => {
    apiMocks.getConnections.mockResolvedValue({
      data: {
        payload: [
          {
            id: 1,
            provider: 'meta',
            status: 'connected',
            display_name: 'Pedro Raphael',
            pages: [],
          },
        ],
      },
    });
    apiMocks.connectionPermissions.mockResolvedValue({
      data: { granted: ['pages_show_list'], missing: ['leads_retrieval'] },
    });

    const wrapper = montar();
    await flushPromises();
    await wrapper
      .find('[data-testid="marketing-toggle-settings"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="marketing-check-permissions"]')
      .trigger('click');
    await flushPromises();

    expect(wrapper.text()).toContain(
      'MARKETING.CONNECTIONS.PERMISSIONS_MISSING'
    );
  });

  // Página sincronizada antes de pedirmos `tasks` não prova nada — e um aviso
  // falso mandaria a pessoa mexer numa permissão que já está certa.
  it('stays quiet about a page synced before we asked for its tasks', async () => {
    apiMocks.getConnections.mockResolvedValue({
      data: {
        payload: [
          {
            id: 1,
            provider: 'meta',
            status: 'connected',
            display_name: 'Pedro Raphael',
            pages: [{ id: '10', name: 'Clinica' }],
          },
        ],
      },
    });

    const wrapper = montar();
    await flushPromises();
    await wrapper
      .find('[data-testid="marketing-toggle-settings"]')
      .trigger('click');

    expect(wrapper.text()).not.toContain('MARKETING.CONNECTIONS.PAGE_LIMITED');
  });
});
