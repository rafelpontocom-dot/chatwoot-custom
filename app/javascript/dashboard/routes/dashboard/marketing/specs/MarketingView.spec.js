import { shallowMount, flushPromises } from '@vue/test-utils';
import { computed } from 'vue';
import MarketingView from '../MarketingView.vue';

const apiMocks = vi.hoisted(() => ({
  getModule: vi.fn(),
  updateModule: vi.fn(),
  getTouchpoints: vi.fn(),
  getSummary: vi.fn(),
}));
const storeMocks = vi.hoisted(() => ({
  currentAccount: { id: 7, permissions: ['administrator'] },
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key, locale: { value: 'pt_BR' } }),
}));
vi.mock('dashboard/api/marketing', () => ({ default: apiMocks }));
vi.mock('dashboard/composables/store', () => ({
  useMapGetter: () => computed(() => storeMocks.currentAccount),
}));

// `shallowMount` stuba os filhos e o conteúdo dos slots some — inclusive o
// botão da engrenagem, que vive no slot `actions` do RaevoPageHeader.
const stubs = {
  RaevoPageHeader: {
    template: '<header><slot name="actions" /><slot /></header>',
  },
  RaevoStamp: { template: '<span />' },
  'router-link': { template: '<a><slot /></a>' },
};

const montar = () => shallowMount(MarketingView, { global: { stubs } });

describe('MarketingView', () => {
  beforeEach(() => {
    storeMocks.currentAccount = { id: 7, permissions: ['administrator'] };
    apiMocks.getModule.mockResolvedValue({ data: { enabled: true } });
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
});
