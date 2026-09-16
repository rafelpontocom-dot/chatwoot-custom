import { flushPromises, shallowMount } from '@vue/test-utils';
import { ref } from 'vue';

import CalendarSettingsDialog from '../CalendarSettingsDialog.vue';
import CalendarAPI from 'dashboard/api/calendar';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

vi.mock('dashboard/composables/store', () => ({
  useMapGetter: () => ref([]),
  useStore: () => ({ dispatch: vi.fn().mockResolvedValue() }),
}));

vi.mock('dashboard/api/calendar', () => ({
  default: {
    getProcedures: vi.fn(),
    getBookingPage: vi.fn(),
    getBookingLinks: vi.fn(),
    getFeegowConnection: vi.fn(),
    updateFeegowConnection: vi.fn(),
    syncFeegowConnection: vi.fn(),
    disconnectFeegow: vi.fn(),
    getFeegowProfessionals: vi.fn(),
    updateBookingPage: vi.fn(),
  },
}));

const mountDialog = (props = {}) =>
  shallowMount(CalendarSettingsDialog, {
    props,
    global: {
      stubs: {
        NextButton: {
          props: ['label'],
          template: '<button v-bind="$attrs">{{ label }}</button>',
        },
        // Sem este stub o `shallowMount` esconde o slot do RaevoField e todos
        // os campos do procedimento desaparecem do teste (CLAUDE.md).
        RaevoField: {
          // `required` com tipo Boolean, como no componente verdadeiro: sem o
          // tipo, o atributo vazio chega como '' e a marca nunca aparece.
          props: {
            label: String,
            error: String,
            errorTestid: String,
            hint: String,
            required: Boolean,
          },
          template: `<div>
            <span class="field-label">{{ label }}<i v-if="required" data-testid="required-mark" /></span>
            <slot control-class="control" field-id="field" described-by="field-error" />
            <p v-if="error" :data-testid="errorTestid">{{ error }}</p>
          </div>`,
        },
      },
    },
  });

describe('CalendarSettingsDialog', () => {
  beforeEach(() => {
    CalendarAPI.getProcedures.mockResolvedValue({ data: [] });
    CalendarAPI.getBookingPage.mockResolvedValue({
      data: {
        active: false,
        public_token: 'public-token',
        duplicate_policy: 'create_new',
        minimum_notice_minutes: 1440,
        maximum_notice_days: 60,
        slot_interval_minutes: 15,
      },
    });
    CalendarAPI.getBookingLinks.mockResolvedValue({ data: [] });
    CalendarAPI.getFeegowConnection.mockResolvedValue({
      data: { connected: false, status: 'disconnected', has_token: false },
    });
    CalendarAPI.getFeegowProfessionals.mockResolvedValue({ data: [] });
  });

  const abrirPaginaDeAgendamento = async () => {
    const wrapper = mountDialog({ tab: 'booking-page' });
    await flushPromises();
    return wrapper;
  };

  // O Feegow é da clínica inteira e vive em Integrações.
  const abrirIntegracoes = async () => {
    const wrapper = mountDialog({ tab: 'integrations' });
    await flushPromises();
    return wrapper;
  };

  it('carrega a página de agendamento quando se abre diretamente nela', async () => {
    // O link da navegação lateral e o recarregar da página abrem já nesta aba.
    // Como ela começava ativa, o watcher não disparava, ninguém chamava
    // `loadBookingPage`, e o painel ficava vazio até se sair e voltar.
    const wrapper = mountDialog({ tab: 'booking-page' });
    await flushPromises();

    expect(CalendarAPI.getBookingPage).toHaveBeenCalled();
    expect(
      wrapper.find('[data-testid="calendar-booking-page-form"]').exists()
    ).toBe(true);
  });

  it('does not ask for the booking page while on integrations', async () => {
    await abrirIntegracoes();

    expect(CalendarAPI.getBookingPage).not.toHaveBeenCalled();
    expect(CalendarAPI.getFeegowConnection).toHaveBeenCalled();
  });

  it('saves the clinic identity shown on the public page', async () => {
    CalendarAPI.updateBookingPage.mockResolvedValue({
      data: {
        active: true,
        public_token: 'public-token',
        clinic_name: 'Clínica Vida',
        duplicate_policy: 'create_new',
        minimum_notice_minutes: 1440,
        maximum_notice_days: 60,
        slot_interval_minutes: 15,
      },
    });
    const wrapper = await abrirPaginaDeAgendamento();

    await wrapper
      .find('[data-testid="calendar-booking-clinic-name"]')
      .setValue('Clínica Vida');
    await wrapper
      .find('[data-testid="calendar-booking-page-form"]')
      .trigger('submit');
    await flushPromises();

    expect(CalendarAPI.updateBookingPage).toHaveBeenCalledWith({
      booking_page: expect.objectContaining({ clinic_name: 'Clínica Vida' }),
    });
  });

  describe('links por procedimento', () => {
    const procedimentos = [
      {
        id: 1,
        name: 'Consulta',
        active: true,
        public_booking_enabled: true,
        public_slug: 'consulta',
        duration_minutes: 50,
      },
      {
        id: 2,
        name: 'Retorno',
        active: true,
        public_booking_enabled: false,
        duration_minutes: 30,
      },
      {
        id: 3,
        name: 'Antigo',
        active: false,
        public_booking_enabled: false,
        duration_minutes: 30,
      },
    ];

    it('mostra também quem não tem autoagendamento, e não os arquivados', async () => {
      CalendarAPI.getProcedures.mockResolvedValue({ data: procedimentos });
      const wrapper = await abrirPaginaDeAgendamento();

      const linhas = wrapper.findAll('[data-testid="calendar-procedure-link"]');
      expect(linhas.map(linha => linha.text())).toEqual([
        expect.stringContaining('Consulta'),
        expect.stringContaining('Retorno'),
      ]);
      expect(
        linhas[0].find('[data-testid="calendar-copy-procedure-link"]').exists()
      ).toBe(true);
      expect(linhas[1].text()).toContain(
        'CALENDAR.SETTINGS.PUBLIC_BOOKING_OFF'
      );
    });

    it('leva ao procedimento novo, pedindo o autoagendamento ligado', async () => {
      CalendarAPI.getProcedures.mockResolvedValue({ data: procedimentos });
      const wrapper = await abrirPaginaDeAgendamento();

      await wrapper
        .find('[data-testid="calendar-enable-procedure-booking"]')
        .trigger('click');

      expect(wrapper.emitted('openProcedure')).toEqual([[2]]);
    });
  });

  it('saves the Feegow token and shows when it expires', async () => {
    CalendarAPI.updateFeegowConnection.mockResolvedValue({
      data: {
        connected: true,
        status: 'connected',
        has_token: true,
        token_expires_at: '2026-12-15T00:00:00Z',
        token_expires_in_days: 90,
      },
    });
    const wrapper = await abrirIntegracoes();

    await wrapper
      .find('[data-testid="calendar-feegow-token"]')
      .setValue('token-da-clinica');
    await wrapper.find('[data-testid="calendar-feegow-save"]').trigger('click');
    await flushPromises();

    expect(CalendarAPI.updateFeegowConnection).toHaveBeenCalledWith({
      feegow_connection: {
        api_token: 'token-da-clinica',
        token_expires_at: '',
      },
    });
    expect(
      wrapper.find('[data-testid="calendar-feegow-expiry"]').text()
    ).toContain('CALENDAR.SETTINGS.FEEGOW.EXPIRES_IN');
  });

  // Token vencido em silêncio é a agenda a parar sem ninguém perceber.
  it('warns in red when the Feegow token has expired', async () => {
    CalendarAPI.getFeegowConnection.mockResolvedValue({
      data: {
        connected: true,
        status: 'error',
        has_token: true,
        token_expires_at: '2026-01-01T00:00:00Z',
        token_expires_in_days: -12,
        token_expired: true,
        last_error: 'Token inválido',
      },
    });
    const wrapper = await abrirIntegracoes();

    const aviso = wrapper.find('[data-testid="calendar-feegow-expiry"]');
    expect(aviso.text()).toContain('CALENDAR.SETTINGS.FEEGOW.EXPIRED');
    expect(aviso.classes().join(' ')).toContain('ruby');
  });

  it('syncs Feegow now and shows the reason when it refuses', async () => {
    CalendarAPI.getFeegowConnection.mockResolvedValue({
      data: {
        connected: true,
        status: 'connected',
        has_token: true,
        token_expires_in_days: 40,
      },
    });
    CalendarAPI.syncFeegowConnection.mockRejectedValue({
      response: {
        data: {
          status: 'error',
          has_token: true,
          last_error: 'Token inválido',
        },
      },
    });
    const wrapper = await abrirIntegracoes();

    await wrapper.find('[data-testid="calendar-feegow-sync"]').trigger('click');
    await flushPromises();

    expect(
      wrapper.find('[data-testid="calendar-feegow-error"]').text()
    ).toContain('Token inválido');
  });
});
