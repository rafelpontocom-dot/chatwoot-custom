import { flushPromises, mount } from '@vue/test-utils';
import { ref } from 'vue';
import PublicBookingApp from '../PublicBookingApp.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    locale: ref('pt_BR'),
    t: key =>
      ({
        'PUBLIC_BOOKING.LOADING': 'Carregando horários disponíveis...',
        'PUBLIC_BOOKING.NO_PROCEDURES':
          'Ainda não há procedimentos disponíveis para agendamento.',
      })[key] || key,
  }),
}));

describe('PublicBookingApp', () => {
  beforeEach(() => {
    vi.spyOn(console, 'warn').mockImplementation(() => {});
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });

  it('shows a clear empty state when the booking page has no published procedures', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => ({
          title: 'Agenda Raevo',
          locale: 'pt_BR',
          procedures: [],
        }),
      })
    );

    const wrapper = mount(PublicBookingApp, {
      props: { bookingPageUrl: '/agendar/token-valido' },
    });
    await flushPromises();

    expect(
      wrapper.find('[data-testid="public-booking-empty-procedures"]').exists()
    ).toBe(true);
    expect(wrapper.text()).not.toContain('Carregando horários disponíveis...');
  });
});
