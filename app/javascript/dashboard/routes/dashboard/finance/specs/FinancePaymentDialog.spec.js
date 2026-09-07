import { flushPromises, mount } from '@vue/test-utils';
import FinancePaymentDialog from '../FinancePaymentDialog.vue';
import FinanceAPI from 'dashboard/api/finance';
import ContactAPI from 'dashboard/api/contacts';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/api/finance', () => ({
  default: { createPayment: vi.fn() },
}));
vi.mock('dashboard/api/contacts', () => ({
  default: { search: vi.fn() },
}));

const DialogStub = {
  template: '<div><slot /><slot name="footer" /></div>',
  methods: { open() {}, close() {} },
};
const ButtonStub = {
  props: ['label'],
  emits: ['click'],
  template:
    '<button v-bind="$attrs" type="button" @click="$emit(\'click\')">{{ label }}</button>',
};

const mountDialog = props =>
  mount(FinancePaymentDialog, {
    props: {
      connections: [
        {
          id: 7,
          provider: 'asaas',
          display_name: 'Conta clínica',
          status: 'connected',
        },
      ],
      ...props,
    },
    global: { stubs: { Dialog: DialogStub, Button: ButtonStub } },
  });

describe('FinancePaymentDialog', () => {
  const ifthenpayConnection = {
    id: 9,
    provider: 'ifthenpay',
    display_name: 'ifthenpay',
    status: 'connected',
    enabled_billing_types: ['multibanco', 'mbway'],
  };

  it('offers only the ifthenpay methods the merchant has a key for', async () => {
    const wrapper = mountDialog({ connections: [ifthenpayConnection] });
    wrapper.vm.open();
    await flushPromises();

    expect(wrapper.vm.billingTypeOptions.map(option => option.value)).toEqual([
      'multibanco',
      'mbway',
    ]);
  });

  it('asks for a mobile number only when charging by MB WAY', async () => {
    const wrapper = mountDialog({ connections: [ifthenpayConnection] });
    wrapper.vm.open();
    await flushPromises();

    wrapper.vm.billingType = 'multibanco';
    await wrapper.vm.$nextTick();
    expect(
      wrapper.find('[data-testid="finance-payment-mobile-number"]').exists()
    ).toBe(false);

    wrapper.vm.billingType = 'mbway';
    await wrapper.vm.$nextTick();
    expect(
      wrapper.find('[data-testid="finance-payment-mobile-number"]').exists()
    ).toBe(true);
  });

  it('never asks a Portuguese charge for a CPF', async () => {
    const wrapper = mountDialog({ connections: [ifthenpayConnection] });
    wrapper.vm.open();
    await flushPromises();

    expect(
      wrapper.find('[data-testid="finance-payment-cpf-cnpj"]').exists()
    ).toBe(false);
  });

  it('sends the MB WAY charge in euros with the mobile number', async () => {
    FinanceAPI.createPayment.mockResolvedValue({ data: { id: 93 } });
    const wrapper = mountDialog({
      connections: [ifthenpayConnection],
      contact: { id: 22, name: 'Cliente PT', phone_number: '+351912345678' },
      market: 'PT',
    });
    wrapper.vm.open();
    await flushPromises();

    wrapper.vm.billingType = 'mbway';
    await wrapper.vm.$nextTick();
    await wrapper
      .get('[data-testid="finance-payment-amount"]')
      .setValue('150,25');
    await wrapper
      .get('[data-testid="finance-payment-due-on"]')
      .setValue('2026-09-30');
    await wrapper
      .get('[data-testid="finance-payment-mobile-number"]')
      .setValue('912345678');
    await wrapper
      .get('[data-testid="finance-payment-submit"]')
      .trigger('click');
    await flushPromises();

    expect(FinanceAPI.createPayment).toHaveBeenCalledWith({
      payment: expect.objectContaining({
        billing_type: 'mbway',
        currency: 'EUR',
        amount_cents: 15025,
        mobile_number: '912345678',
      }),
    });
  });

  it('creates a charge for the selected contact', async () => {
    vi.useFakeTimers();
    ContactAPI.search.mockResolvedValue({
      data: { payload: [{ id: 22, name: 'Pedro Raevo' }] },
    });
    FinanceAPI.createPayment.mockResolvedValue({ data: { id: 92 } });
    const wrapper = mountDialog();
    wrapper.vm.open();

    await wrapper
      .get('[data-testid="finance-payment-contact-search"]')
      .setValue('Pedro');
    await vi.advanceTimersByTimeAsync(300);
    await flushPromises();
    await wrapper.get('button').trigger('click');
    await wrapper
      .get('[data-testid="finance-payment-amount"]')
      .setValue('150,25');
    await wrapper
      .get('[data-testid="finance-payment-due-on"]')
      .setValue('2026-09-01');
    await wrapper
      .get('[data-testid="finance-payment-cpf-cnpj"]')
      .setValue('12345678909');
    await wrapper
      .get('[data-testid="finance-payment-description"]')
      .setValue('Consulta');
    await wrapper
      .get('[data-testid="finance-payment-submit"]')
      .trigger('click');
    await flushPromises();

    expect(FinanceAPI.createPayment).toHaveBeenCalledWith({
      payment: {
        contact_id: 22,
        finance_provider_connection_id: 7,
        amount_cents: 15025,
        billing_type: 'pix',
        due_on: '2026-09-01',
        currency: 'BRL',
        cpf_cnpj: '12345678909',
        description: 'Consulta',
      },
    });
    expect(wrapper.emitted('created')).toEqual([[{ id: 92 }]]);
    vi.useRealTimers();
  });

  it('records an external EUR charge without requesting CPF or CNPJ', async () => {
    vi.useFakeTimers();
    ContactAPI.search.mockResolvedValue({
      data: { payload: [{ id: 22, name: 'Pedro Raevo' }] },
    });
    FinanceAPI.createPayment.mockResolvedValue({ data: { id: 93 } });
    const wrapper = mountDialog({
      market: 'PT',
      connections: [
        {
          id: 8,
          provider: 'manual',
          display_name: 'Registo externo',
          status: 'connected',
        },
      ],
    });
    wrapper.vm.open();

    await wrapper
      .get('[data-testid="finance-payment-contact-search"]')
      .setValue('Pedro');
    await vi.advanceTimersByTimeAsync(300);
    await flushPromises();
    await wrapper.get('button').trigger('click');
    await wrapper
      .get('[data-testid="finance-payment-amount"]')
      .setValue('90,00');
    await wrapper
      .get('[data-testid="finance-payment-due-on"]')
      .setValue('2026-09-04');
    await wrapper
      .get('[data-testid="finance-payment-description"]')
      .setValue('Consulta externa');

    expect(
      wrapper.find('[data-testid="finance-payment-cpf-cnpj"]').exists()
    ).toBe(false);

    await wrapper
      .get('[data-testid="finance-payment-submit"]')
      .trigger('click');
    await flushPromises();

    expect(FinanceAPI.createPayment).toHaveBeenCalledWith({
      payment: {
        contact_id: 22,
        finance_provider_connection_id: 8,
        amount_cents: 9000,
        billing_type: 'other',
        due_on: '2026-09-04',
        currency: 'EUR',
        description: 'Consulta externa',
      },
    });
    vi.useRealTimers();
  });

  it('requires at least R$ 5,00 before creating an Asaas charge', async () => {
    const wrapper = mountDialog({ contact: { id: 22, name: 'Pedro Raevo' } });
    wrapper.vm.open();

    await wrapper
      .get('[data-testid="finance-payment-amount"]')
      .setValue('1,00');
    await wrapper
      .get('[data-testid="finance-payment-due-on"]')
      .setValue('2026-09-01');
    await wrapper
      .get('[data-testid="finance-payment-cpf-cnpj"]')
      .setValue('12345678909');

    expect(
      wrapper
        .get('[data-testid="finance-payment-submit"]')
        .attributes('disabled')
    ).toBeDefined();
    expect(wrapper.text()).toContain('FINANCE.PAYMENTS.ASAAS_MINIMUM_AMOUNT');
    expect(FinanceAPI.createPayment).not.toHaveBeenCalled();
  });
});
