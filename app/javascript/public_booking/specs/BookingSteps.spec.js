import { mount } from '@vue/test-utils';
import { ref } from 'vue';
import BookingDone from '../components/BookingDone.vue';
import BookingForm from '../components/BookingForm.vue';
import BookingMonth from '../components/BookingMonth.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ locale: ref('pt_BR'), t: key => key }),
}));

const QUESTIONS = [
  { key: 'full_name', label: 'Nome', kind: 'text', required: true },
  { key: 'whatsapp', label: 'WhatsApp', kind: 'phone', required: true },
  { key: 'cpf', label: 'CPF', kind: 'cpf', required: true },
];

const booking = overrides => ({
  token: 'abc',
  status: 'confirmed',
  starts_at: '2026-09-30T14:00:00Z',
  ends_at: '2026-09-30T14:50:00Z',
  timezone: 'America/Recife',
  resources: [{ type: 'user', name: 'Dr. Bruno' }],
  clinic: { name: 'Clínica Vida' },
  procedure: { title: 'Avaliação', duration_minutes: 50 },
  payment: { method: 'on_site' },
  can_reschedule: true,
  can_cancel: true,
  cancel_reason_required: true,
  ...overrides,
});

describe('BookingMonth', () => {
  it('starts on Monday and keeps days without room visible but not selectable', async () => {
    const wrapper = mount(BookingMonth, {
      props: { month: new Date(2026, 8, 1), availableDays: ['2026-09-23'] },
    });

    // 1 de setembro de 2026 é terça: uma célula vazia antes dele.
    const cells = wrapper.findAll('[data-testid="public-booking-month"] > *');
    expect(cells[7].element.tagName).toBe('SPAN');
    expect(cells[8].attributes('data-day')).toBe('2026-09-01');

    const closed = wrapper.find('[data-day="2026-09-22"]');
    expect(closed.attributes('aria-disabled')).toBe('true');
    await closed.trigger('click');
    expect(wrapper.emitted('select')).toBeUndefined();

    await wrapper.find('[data-day="2026-09-23"]').trigger('click');
    expect(wrapper.emitted('select')).toEqual([['2026-09-23']]);
  });
});

describe('BookingForm', () => {
  const mountForm = props =>
    mount(BookingForm, { props: { questions: QUESTIONS, ...props } });

  it('masks phone and CPF and refuses an invalid CPF', async () => {
    const wrapper = mountForm();
    await wrapper
      .find('[data-testid="public-booking-answer-whatsapp"]')
      .setValue('81999990000');
    await wrapper
      .find('[data-testid="public-booking-answer-cpf"]')
      .setValue('11111111111');
    await wrapper
      .find('[data-testid="public-booking-answer-full_name"]')
      .setValue('Rita Souza');
    await wrapper.find('[data-testid="public-booking-consent"]').setValue(true);

    expect(
      wrapper.find('[data-testid="public-booking-answer-whatsapp"]').element
        .value
    ).toBe('(81) 99999-0000');

    await wrapper.find('[data-testid="public-booking-form"]').trigger('submit');
    expect(wrapper.text()).toContain('PUBLIC_BOOKING.ERRORS.CPF');
    expect(wrapper.emitted('submit')).toBeUndefined();

    await wrapper
      .find('[data-testid="public-booking-answer-cpf"]')
      .setValue('52998224725');
    await wrapper.find('[data-testid="public-booking-form"]').trigger('submit');
    expect(wrapper.emitted('submit')[0][0]).toMatchObject({
      answers: { cpf: '529.982.247-25', whatsapp: '(81) 99999-0000' },
      paymentMethod: 'on_site',
    });
  });

  it('shows only the payment methods the page offers', () => {
    const wrapper = mountForm({
      payment: {
        enabled: true,
        methods: ['on_site'],
        mode: 'full',
        price_cents: 25000,
        charge_cents: 25000,
        currency: 'BRL',
      },
    });

    expect(
      wrapper.find('[data-testid="public-booking-method-on_site"]').exists()
    ).toBe(true);
    expect(
      wrapper.find('[data-testid="public-booking-method-pix"]').exists()
    ).toBe(false);
    expect(
      wrapper.find('[data-testid="public-booking-submit"]').text()
    ).toContain('PUBLIC_BOOKING.CONFIRM');
  });
});

describe('BookingDone', () => {
  it('asks for a reason before cancelling', async () => {
    const wrapper = mount(BookingDone, { props: { booking: booking() } });

    await wrapper
      .find('[data-testid="public-booking-cancel"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="public-booking-cancel-confirm"]')
      .trigger('click');
    expect(wrapper.emitted('cancel')).toBeUndefined();

    await wrapper
      .find('[data-testid="public-booking-cancel-reason"]')
      .setValue('Viagem');
    await wrapper
      .find('[data-testid="public-booking-cancel-confirm"]')
      .trigger('click');
    expect(wrapper.emitted('cancel')).toEqual([['Viagem']]);
  });

  it('closes the cancel form once the booking comes back canceled', async () => {
    const wrapper = mount(BookingDone, { props: { booking: booking() } });
    await wrapper
      .find('[data-testid="public-booking-cancel"]')
      .trigger('click');

    await wrapper.setProps({
      booking: booking({
        status: 'canceled',
        can_cancel: false,
        can_reschedule: false,
      }),
    });

    expect(
      wrapper.find('[data-testid="public-booking-cancel-form"]').exists()
    ).toBe(false);
    expect(wrapper.find('[data-testid="public-booking-ics"]').exists()).toBe(
      false
    );
  });

  it('links to the charge while payment is pending', () => {
    const wrapper = mount(BookingDone, {
      props: {
        booking: booking({
          status: 'awaiting_payment',
          payment: {
            method: 'pix',
            amount_cents: 5000,
            currency: 'BRL',
            invoice_url: 'https://pay.example/1',
          },
        }),
      },
    });

    expect(
      wrapper
        .find('[data-testid="public-booking-open-payment"]')
        .attributes('href')
    ).toBe('https://pay.example/1');
    expect(wrapper.text()).toContain('PUBLIC_BOOKING.DONE.PAYMENT_PENDING');
  });
});
