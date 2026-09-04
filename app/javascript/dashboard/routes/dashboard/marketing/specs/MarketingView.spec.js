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

  // O botão de ligar existia sem caminho possível: sem editor de destino, ele
  // só devolvia a validação crua do Rails.
  it('refuses to turn on a form with nowhere to put the lead', async () => {
    apiMocks.getLeadForms.mockResolvedValue({
      data: {
        payload: [
          {
            id: 9,
            name: 'Forms Diagnóstico',
            page_name: 'Clinica',
            active: false,
            questions: [],
            crm_destination: {},
          },
        ],
      },
    });

    const wrapper = montar();
    await flushPromises();
    await wrapper
      .find('[data-testid="marketing-toggle-settings"]')
      .trigger('click');

    expect(wrapper.text()).toContain('MARKETING.CONNECTIONS.NEEDS_DESTINATION');
  });

  it('saves where the lead lands and which question fills which field', async () => {
    apiMocks.getLeadForms.mockResolvedValue({
      data: {
        payload: [
          {
            id: 9,
            name: 'Forms Diagnóstico',
            page_name: 'Clinica',
            active: false,
            questions: [{ key: 'full_name', label: 'Seu nome' }],
            crm_destination: {
              kanban_board_id: 1,
              kanban_stage_id: 2,
              inbox_id: 3,
              sub_origem: '[ORG] Instagram',
            },
            field_mapping: { full_name: 'name' },
          },
        ],
      },
    });
    apiMocks.updateLeadForm.mockResolvedValue({ data: {} });
    boardsMocks.getSettings.mockResolvedValue({
      data: {
        stages: [{ id: 2, name: 'Novo' }],
        allowed_inbox_ids: [3],
        custom_field_definitions: [
          { key: 'sub_origem', options: ['[MP] Meta', '[ORG] Instagram'] },
        ],
      },
    });

    const wrapper = montar();
    await flushPromises();
    await wrapper
      .find('[data-testid="marketing-toggle-settings"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="marketing-configure-form"]')
      .trigger('click');
    await flushPromises();
    await wrapper
      .find('[data-testid="marketing-save-form-destination"]')
      .trigger('submit');
    await flushPromises();

    expect(apiMocks.updateLeadForm).toHaveBeenCalledWith(9, {
      lead_form: {
        crm_destination: {
          kanban_board_id: 1,
          kanban_stage_id: 2,
          inbox_id: 3,
          origem_do_lead: '',
          sub_origem: '[ORG] Instagram',
        },
        field_mapping: { full_name: 'name' },
      },
    });
  });

  // Origem e sub-origem sao `select` no card: valor fora das opcoes fica
  // gravado e o campo aparece vazio. A lista tem de vir do quadro escolhido.
  it('offers only the origins the chosen board actually has', async () => {
    apiMocks.getLeadForms.mockResolvedValue({
      data: {
        payload: [
          {
            id: 9,
            name: 'Forms Diagnóstico',
            active: false,
            questions: [],
            crm_destination: { kanban_board_id: 1 },
          },
        ],
      },
    });
    boardsMocks.getSettings.mockResolvedValue({
      data: {
        stages: [],
        allowed_inbox_ids: [],
        custom_field_definitions: [
          { key: 'origem_do_lead', options: ['Mídia Paga', 'Indicação'] },
        ],
      },
    });

    const wrapper = montar();
    await flushPromises();
    await wrapper
      .find('[data-testid="marketing-toggle-settings"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="marketing-configure-form"]')
      .trigger('click');
    await flushPromises();

    expect(wrapper.text()).toContain('Indicação');
    expect(wrapper.text()).toContain('MARKETING.CONNECTIONS.ORIGIN_DEFAULT');
  });

  // Desconectar deixava a linha no banco e a tela escondia o botão de
  // conectar: sem saída, e "Atualizar páginas" ainda chamava o Meta sem token.
  it('offers connecting again after a disconnect', async () => {
    apiMocks.getConnections.mockResolvedValue({
      data: {
        payload: [
          {
            id: 1,
            provider: 'meta',
            status: 'disconnected',
            display_name: 'Pedro Raphael',
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

    expect(
      wrapper.find('[data-testid="marketing-connect-meta"]').exists()
    ).toBe(true);
    expect(wrapper.text()).not.toContain('MARKETING.CONNECTIONS.SYNC_PAGES');
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
