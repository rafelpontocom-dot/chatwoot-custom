import { flushPromises, shallowMount } from '@vue/test-utils';
import { ref } from 'vue';
import FinanceView from '../FinanceView.vue';
import FinanceAPI from 'dashboard/api/finance';
import { copyTextToClipboard } from 'shared/helpers/clipboard';

const mockPush = vi.fn();
const mockDispatch = vi.fn();
const currentAccount = ref({ permissions: ['administrator'] });

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '1' } }),
  useRouter: () => ({ push: mockPush }),
}));
vi.mock('dashboard/helper/URLHelper', () => ({
  frontendURL: path => path,
  conversationUrl: ({ accountId, id }) =>
    `/app/accounts/${accountId}/conversations/${id}`,
}));
vi.mock('dashboard/api/finance', () => ({
  default: {
    getModule: vi.fn(),
    updateModule: vi.fn(),
    getProviderConnections: vi.fn(),
    createProviderConnection: vi.fn(),
    updateProviderConnection: vi.fn(),
    verifyProviderConnection: vi.fn(),
    deleteProviderConnection: vi.fn(),
    getPayments: vi.fn(),
    getPaymentsSummary: vi.fn(),
    getPayment: vi.fn(),
    getWebhookDeliveries: vi.fn(),
    retryWebhookDelivery: vi.fn(),
  },
}));
vi.mock('dashboard/composables/store', async () => {
  const { computed } = await vi.importActual('vue');

  return {
    useMapGetter: key => {
      if (key === 'getCurrentAccount') return currentAccount;

      return computed(() => [{ id: 7, name: 'Ana Secretaria' }]);
    },
    useStore: () => ({
      dispatch: mockDispatch,
      getters: { 'draftMessages/get': () => '' },
    }),
  };
});

vi.mock('shared/helpers/clipboard', () => ({
  copyTextToClipboard: vi.fn(),
}));

const FinancePaymentDetailsDialogStub = {
  setup(_, { expose }) {
    expose({ open: vi.fn() });
  },
  template: '<div />',
};

// Raevo · Sereno — o Financeiro abre no painel operacional. Módulo, segurança
// e conexões vivem atrás da engrenagem. Testes de configuração precisam abri-la.
const openSettings = async wrapper => {
  await wrapper
    .find('[data-testid="finance-toggle-settings"]')
    .trigger('click');
  await flushPromises();
};

const mountFinance = () =>
  shallowMount(FinanceView, {
    global: {
      stubs: {
        Button: true,
        FinancePaymentDetailsDialog: FinancePaymentDetailsDialogStub,
        // shallowMount stuba o cabeçalho e engoliria a engrenagem que vive no
        // slot #actions. Ver AGENTS.md, "Armadilha conhecida em testes".
        RaevoPageHeader: {
          template:
            '<header><slot name="actions" /><slot name="filters" /><slot name="tabs" /><slot /></header>',
        },
      },
    },
  });

describe('FinanceView', () => {
  beforeEach(() => {
    currentAccount.value = { permissions: ['administrator'] };
    FinanceAPI.getProviderConnections.mockResolvedValue({ data: [] });
    FinanceAPI.getPayments.mockResolvedValue({ data: [] });
    FinanceAPI.getPaymentsSummary.mockResolvedValue({
      data: { open: [], received: [], overdue: [] },
    });
    FinanceAPI.getWebhookDeliveries.mockResolvedValue({ data: [] });
    copyTextToClipboard.mockResolvedValue();
  });

  it('shows the controlled activation state before exposing provider setup', async () => {
    FinanceAPI.getModule.mockResolvedValue({
      data: { enabled: false, market: 'BR', lock_version: 0 },
    });
    const wrapper = mountFinance();
    await flushPromises();
    await openSettings(wrapper);

    expect(wrapper.find('[data-testid="finance-module-toggle"]').exists()).toBe(
      true
    );
    expect(wrapper.find('[data-testid="finance-asaas-api-key"]').exists()).toBe(
      false
    );
  });

  it('shows Asaas setup only after the module is enabled for Brazil', async () => {
    FinanceAPI.getModule.mockResolvedValue({
      data: { enabled: true, market: 'BR', lock_version: 0 },
    });
    const wrapper = mountFinance();
    await flushPromises();
    await openSettings(wrapper);

    expect(wrapper.find('[data-testid="finance-asaas-api-key"]').exists()).toBe(
      true
    );
  });

  it('keeps provider configuration out of the secretary workspace', async () => {
    currentAccount.value = { permissions: ['agent'] };
    FinanceAPI.getModule.mockResolvedValue({
      data: { enabled: true, market: 'BR', lock_version: 0 },
    });
    FinanceAPI.getProviderConnections.mockResolvedValue({
      data: [{ id: 7, provider: 'asaas', status: 'connected' }],
    });
    const wrapper = mountFinance();
    await flushPromises();

    expect(wrapper.find('[data-testid="finance-module-toggle"]').exists()).toBe(
      false
    );
    expect(wrapper.find('[data-testid="finance-asaas-api-key"]').exists()).toBe(
      false
    );
    expect(wrapper.find('[data-testid="finance-new-payment"]').exists()).toBe(
      true
    );
  });

  it('requires explicit confirmation before disabling finance', async () => {
    FinanceAPI.getModule.mockResolvedValue({
      data: { enabled: true, market: 'BR', lock_version: 0 },
    });
    FinanceAPI.updateModule.mockResolvedValue({
      data: { enabled: false, market: 'BR', lock_version: 1 },
    });
    const wrapper = mountFinance();
    await flushPromises();
    await openSettings(wrapper);
    const toggle = wrapper.get('[data-testid="finance-module-toggle"]');

    await toggle.trigger('click');

    expect(FinanceAPI.updateModule).not.toHaveBeenCalled();

    await toggle.trigger('click');
    await flushPromises();

    expect(FinanceAPI.updateModule).toHaveBeenCalledWith({
      finance_module: {
        enabled: false,
        market: 'BR',
        default_payment_provider: null,
        lock_version: 0,
        confirm_disable: true,
      },
    });
  });

  it('offers a manual finance control for an enabled Portugal account', async () => {
    FinanceAPI.getModule.mockResolvedValue({
      data: { enabled: true, market: 'PT', lock_version: 0 },
    });
    FinanceAPI.createProviderConnection.mockResolvedValue({
      data: { id: 8, provider: 'manual', status: 'connected' },
    });
    const wrapper = mountFinance();
    await flushPromises();
    await openSettings(wrapper);

    const enableManual = wrapper.get('[data-testid="finance-manual-enable"]');
    await enableManual.trigger('click');
    await flushPromises();

    expect(FinanceAPI.createProviderConnection).toHaveBeenCalledWith({
      provider_connection: {
        provider: 'manual',
        environment: 'production',
        display_name: 'FINANCE.CONNECTIONS.MANUAL_NAME',
        status: 'connected',
      },
    });
  });

  it('offers credential verification after an Asaas connection is saved', async () => {
    FinanceAPI.getModule.mockResolvedValue({
      data: { enabled: true, market: 'BR', lock_version: 0 },
    });
    FinanceAPI.getProviderConnections.mockResolvedValue({
      data: [{ id: 7, provider: 'asaas', status: 'pending' }],
    });
    const wrapper = mountFinance();
    await flushPromises();
    await openSettings(wrapper);

    expect(wrapper.find('[data-testid="finance-asaas-verify"]').exists()).toBe(
      true
    );
  });

  it('explains the next action when the Asaas webhook needs attention', async () => {
    FinanceAPI.getModule.mockResolvedValue({
      data: { enabled: true, market: 'BR', lock_version: 0 },
    });
    FinanceAPI.getProviderConnections.mockResolvedValue({
      data: [{ id: 7, provider: 'asaas', status: 'attention' }],
    });
    const wrapper = mountFinance();
    await flushPromises();
    await openSettings(wrapper);

    expect(
      wrapper.get('[data-testid="finance-asaas-webhook-attention"]').text()
    ).toContain('FINANCE.CONNECTIONS.WEBHOOK_ATTENTION');
  });

  it('reprocesses a failed webhook delivery from the connection alert', async () => {
    FinanceAPI.getModule.mockResolvedValue({
      data: { enabled: true, market: 'BR', lock_version: 0 },
    });
    FinanceAPI.getProviderConnections.mockResolvedValue({
      data: [{ id: 7, provider: 'asaas', status: 'attention' }],
    });
    FinanceAPI.getWebhookDeliveries.mockResolvedValue({
      data: [
        {
          id: 11,
          processing_status: 'failed',
          received_at: '2026-08-27T10:30:00Z',
          error_message:
            'Webhook processing failed: ActiveRecord::RecordNotFound',
        },
      ],
    });
    FinanceAPI.retryWebhookDelivery.mockResolvedValue({
      data: { id: 11, processing_status: 'processed' },
    });
    const wrapper = mountFinance();
    await flushPromises();
    await openSettings(wrapper);

    await wrapper
      .get('[data-testid="finance-webhook-delivery-retry-11"]')
      .trigger('click');
    await flushPromises();

    expect(FinanceAPI.retryWebhookDelivery).toHaveBeenCalledWith(7, 11);
  });

  it('requires confirmation before disconnecting an Asaas connection', async () => {
    FinanceAPI.getModule.mockResolvedValue({
      data: { enabled: true, market: 'BR', lock_version: 0 },
    });
    FinanceAPI.getProviderConnections.mockResolvedValue({
      data: [{ id: 7, provider: 'asaas', status: 'connected' }],
    });
    FinanceAPI.deleteProviderConnection.mockResolvedValue({});
    const wrapper = mountFinance();
    await flushPromises();
    await openSettings(wrapper);

    const disconnect = wrapper.find('[data-testid="finance-asaas-disconnect"]');
    expect(disconnect.exists()).toBe(true);

    await disconnect.trigger('click');
    expect(FinanceAPI.deleteProviderConnection).not.toHaveBeenCalled();

    await disconnect.trigger('click');
    await flushPromises();

    expect(FinanceAPI.deleteProviderConnection).toHaveBeenCalledWith(7);
  });

  it('shows a disconnect-specific error when disconnecting the provider fails', async () => {
    FinanceAPI.getModule.mockResolvedValue({
      data: { enabled: true, market: 'BR', lock_version: 0 },
    });
    FinanceAPI.getProviderConnections.mockResolvedValue({
      data: [{ id: 7, provider: 'asaas', status: 'connected' }],
    });
    FinanceAPI.deleteProviderConnection.mockRejectedValue({});
    const wrapper = mountFinance();
    await flushPromises();
    await openSettings(wrapper);

    const disconnect = wrapper.get('[data-testid="finance-asaas-disconnect"]');
    await disconnect.trigger('click');
    await disconnect.trigger('click');
    await flushPromises();

    expect(wrapper.text()).toContain('FINANCE.ERROR.DISCONNECT');
  });

  it('shows recent charges with the customer context', async () => {
    FinanceAPI.getModule.mockResolvedValue({
      data: { enabled: true, market: 'BR', lock_version: 0 },
    });
    FinanceAPI.getPayments.mockResolvedValue({
      data: [
        {
          id: 12,
          status: 'pending',
          amount_cents: 15025,
          currency: 'BRL',
          invoice_url: 'https://pay.example/12',
          contact: { name: 'Pedro Raevo' },
        },
      ],
    });
    const wrapper = mountFinance();
    await flushPromises();

    expect(
      wrapper.find('[data-testid="finance-payments-list"]').text()
    ).toContain('Pedro Raevo');
    expect(
      wrapper.find('[data-testid="finance-payment-link"]').attributes('href')
    ).toBe('https://pay.example/12');
    await wrapper
      .find('[data-testid="finance-payment-details"]')
      .trigger('click');
    expect(wrapper.vm.$refs.paymentDetailsDialog.open).toHaveBeenCalledWith(12);
  });

  it('prepares the payment link in the linked conversation from the finance list', async () => {
    FinanceAPI.getModule.mockResolvedValue({
      data: { enabled: true, market: 'BR', lock_version: 0 },
    });
    FinanceAPI.getPayments.mockResolvedValue({
      data: [
        {
          id: 12,
          status: 'pending',
          amount_cents: 15025,
          currency: 'BRL',
          invoice_url: 'https://pay.example/12',
          contact: { name: 'Pedro Raevo' },
          kanban_card: { id: 44, conversation_id: 42 },
        },
      ],
    });
    const wrapper = mountFinance();
    await flushPromises();

    await wrapper
      .get('[data-testid="finance-payment-send-link"]')
      .trigger('click');

    expect(mockDispatch).toHaveBeenCalledWith('draftMessages/set', {
      key: 'draft-42-REPLY',
      message: 'https://pay.example/12',
    });
    expect(mockPush).toHaveBeenCalledWith({
      path: '/app/accounts/1/conversations/42',
    });
  });

  it('copies a payment link from the finance list without leaving the workspace', async () => {
    FinanceAPI.getModule.mockResolvedValue({
      data: { enabled: true, market: 'BR', lock_version: 0 },
    });
    FinanceAPI.getPayments.mockResolvedValue({
      data: [
        {
          id: 12,
          status: 'pending',
          amount_cents: 15025,
          currency: 'BRL',
          invoice_url: 'https://pay.example/12',
          contact: { name: 'Pedro Raevo' },
        },
      ],
    });
    const wrapper = mountFinance();
    await flushPromises();

    await wrapper
      .get('[data-testid="finance-payment-copy-link"]')
      .trigger('click');

    expect(copyTextToClipboard).toHaveBeenCalledWith('https://pay.example/12');
    expect(
      wrapper
        .get('[data-testid="finance-payment-copy-link"]')
        .attributes('aria-label')
    ).toBe('FINANCE.PAYMENTS.COPIED');
  });

  it('offers guided charge creation when a payment provider is connected', async () => {
    FinanceAPI.getModule.mockResolvedValue({
      data: { enabled: true, market: 'BR', lock_version: 0 },
    });
    FinanceAPI.getProviderConnections.mockResolvedValue({
      data: [{ id: 7, provider: 'asaas', status: 'connected' }],
    });
    const wrapper = mountFinance();
    await flushPromises();

    expect(wrapper.find('[data-testid="finance-new-payment"]').exists()).toBe(
      true
    );
  });

  it('shows expected, received and overdue totals for the active payment filters', async () => {
    FinanceAPI.getModule.mockResolvedValue({
      data: { enabled: true, market: 'BR', lock_version: 0 },
    });
    FinanceAPI.getPaymentsSummary.mockResolvedValue({
      data: {
        open: [{ currency: 'BRL', count: 1, amount_cents: 15_025 }],
        received: [{ currency: 'BRL', count: 2, amount_cents: 30_000 }],
        overdue: [],
      },
    });
    const wrapper = mountFinance();
    await flushPromises();

    const summary = wrapper.get('[data-testid="finance-payments-summary"]');
    expect(summary.text()).toContain('FINANCE.PAYMENTS.SUMMARY.OPEN');
    expect(summary.text()).toContain('FINANCE.PAYMENTS.SUMMARY.RECEIVED');
    expect(summary.text()).toContain('150,25');
  });

  it('sends compact payment filters to the server', async () => {
    FinanceAPI.getModule.mockResolvedValue({
      data: { enabled: true, market: 'BR', lock_version: 0 },
    });
    const wrapper = mountFinance();
    await flushPromises();
    FinanceAPI.getPayments.mockClear();

    await wrapper
      .get('[data-testid="finance-payment-search"]')
      .setValue('Pedro Raevo');
    await wrapper
      .get('[data-testid="finance-payment-status-filter"]')
      .setValue('pending');
    await wrapper
      .get('[data-testid="finance-payment-filters"]')
      .trigger('submit');
    await flushPromises();

    expect(FinanceAPI.getPayments).toHaveBeenCalledWith({
      query: 'Pedro Raevo',
      status: 'pending',
    });
  });

  it('includes the selected commercial owner in payment filters', async () => {
    FinanceAPI.getModule.mockResolvedValue({
      data: { enabled: true, market: 'BR', lock_version: 0 },
    });
    const wrapper = mountFinance();
    await flushPromises();
    FinanceAPI.getPayments.mockClear();

    await wrapper
      .get('[data-testid="finance-payment-owner-filter"]')
      .setValue('7');
    await wrapper
      .get('[data-testid="finance-payment-filters"]')
      .trigger('submit');
    await flushPromises();

    expect(FinanceAPI.getPayments).toHaveBeenCalledWith({ owner_id: 7 });
  });
});
