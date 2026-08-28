import { flushPromises, mount } from '@vue/test-utils';
import FinancePaymentDetailsDialog from '../FinancePaymentDetailsDialog.vue';
import FinanceAPI from 'dashboard/api/finance';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/api/finance', () => ({
  default: {
    getPayment: vi.fn(),
    cancelPayment: vi.fn(),
    markPaymentReceived: vi.fn(),
    requestPaymentRefund: vi.fn(),
  },
}));

const DialogStub = {
  template: '<div><slot /></div>',
  methods: { open() {} },
};

describe('FinancePaymentDetailsDialog', () => {
  it('shows the safe payment event timeline without raw provider metadata', async () => {
    FinanceAPI.getPayment.mockResolvedValue({
      data: {
        id: 12,
        status: 'received',
        description: 'Consulta',
        events: [
          {
            id: 7,
            event_type: 'PAYMENT_RECEIVED',
            occurred_at: '2026-09-01T10:30:00Z',
            metadata: { payment: { customer: 'must-not-render' } },
          },
        ],
      },
    });
    const wrapper = mount(FinancePaymentDetailsDialog, {
      global: { stubs: { Dialog: DialogStub } },
    });

    await wrapper.vm.open(12);
    await flushPromises();

    expect(FinanceAPI.getPayment).toHaveBeenCalledWith(12);
    expect(wrapper.text()).toContain(
      'FINANCE.PAYMENTS.DETAIL.EVENT_TYPES.PAYMENT_RECEIVED'
    );
    expect(wrapper.text()).not.toContain('must-not-render');
  });

  it('shows the operational payment details and secure invoice link', async () => {
    FinanceAPI.getPayment.mockResolvedValue({
      data: {
        id: 15,
        provider: 'asaas',
        status: 'pending',
        description: 'Consulta de retorno',
        amount_cents: 15025,
        currency: 'BRL',
        billing_type: 'pix',
        due_on: '2026-09-10',
        invoice_url: 'https://pay.example/15',
        events: [],
      },
    });
    const wrapper = mount(FinancePaymentDetailsDialog, {
      global: { stubs: { Dialog: DialogStub } },
    });

    await wrapper.vm.open(15);
    await flushPromises();

    expect(
      wrapper.get('[data-testid="finance-payment-detail-amount"]').text()
    ).toContain('150');
    expect(
      wrapper.get('[data-testid="finance-payment-detail-method"]').text()
    ).toContain('FINANCE.PAYMENTS.TYPES.PIX');
    expect(
      wrapper
        .get('[data-testid="finance-payment-detail-link"]')
        .attributes('href')
    ).toBe('https://pay.example/15');
  });

  it('cancels a pending charge from its detail after explicit confirmation', async () => {
    FinanceAPI.getPayment.mockResolvedValue({
      data: { id: 12, status: 'pending', description: 'Consulta', events: [] },
    });
    FinanceAPI.cancelPayment.mockResolvedValue({
      data: { id: 12, status: 'canceled', description: 'Consulta', events: [] },
    });
    const wrapper = mount(FinancePaymentDetailsDialog, {
      global: { stubs: { Dialog: DialogStub } },
    });

    await wrapper.vm.open(12);
    await flushPromises();

    const cancel = wrapper.get('[data-testid="finance-payment-cancel"]');
    await cancel.trigger('click');
    expect(FinanceAPI.cancelPayment).not.toHaveBeenCalled();

    await cancel.trigger('click');
    await flushPromises();

    expect(FinanceAPI.cancelPayment).toHaveBeenCalledWith(12);
    expect(wrapper.emitted('canceled')[0][0]).toMatchObject({
      id: 12,
      status: 'canceled',
    });
  });

  it('marks a pending manual charge as received after explicit confirmation', async () => {
    FinanceAPI.getPayment.mockResolvedValue({
      data: {
        id: 13,
        provider: 'manual',
        status: 'pending',
        description: 'Consulta externa',
        events: [],
      },
    });
    FinanceAPI.markPaymentReceived.mockResolvedValue({
      data: {
        id: 13,
        provider: 'manual',
        status: 'received',
        description: 'Consulta externa',
        events: [],
      },
    });
    const wrapper = mount(FinancePaymentDetailsDialog, {
      global: { stubs: { Dialog: DialogStub } },
    });

    await wrapper.vm.open(13);
    await flushPromises();

    const receive = wrapper.get(
      '[data-testid="finance-payment-mark-received"]'
    );
    await receive.trigger('click');
    expect(FinanceAPI.markPaymentReceived).not.toHaveBeenCalled();

    await receive.trigger('click');
    await flushPromises();

    expect(FinanceAPI.markPaymentReceived).toHaveBeenCalledWith(13);
    expect(wrapper.emitted('received')[0][0]).toMatchObject({
      id: 13,
      status: 'received',
    });
  });

  it('requests an Asaas refund after explicit confirmation without changing the payment locally', async () => {
    FinanceAPI.getPayment.mockResolvedValue({
      data: {
        id: 14,
        provider: 'asaas',
        billing_type: 'pix',
        status: 'received',
        description: 'Consulta',
        events: [],
      },
    });
    FinanceAPI.requestPaymentRefund.mockResolvedValue({
      data: { id: 14, provider: 'asaas', status: 'received', events: [] },
    });
    const wrapper = mount(FinancePaymentDetailsDialog, {
      global: { stubs: { Dialog: DialogStub } },
    });

    await wrapper.vm.open(14);
    await flushPromises();

    const refund = wrapper.get('[data-testid="finance-payment-refund"]');
    await refund.trigger('click');
    expect(FinanceAPI.requestPaymentRefund).not.toHaveBeenCalled();

    await refund.trigger('click');
    await flushPromises();

    expect(FinanceAPI.requestPaymentRefund).toHaveBeenCalledWith(14, '');
    expect(wrapper.emitted('refundRequested')[0][0]).toMatchObject({
      id: 14,
      status: 'received',
    });
  });
});
