import { shallowMount } from '@vue/test-utils';
import { ref } from 'vue';

import CalendarSettingsView from '../CalendarSettingsView.vue';

const rotaAtual = ref({ params: { section: 'procedures' } });
const empurra = vi.fn();
const carregaTudo = vi.fn();

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

vi.mock('vue-router', () => ({
  useRoute: () => rotaAtual.value,
  useRouter: () => ({ replace: vi.fn(), push: empurra }),
}));

vi.mock('dashboard/composables/store', () => ({
  useMapGetter: () => ref(7),
  useStore: () => ({ dispatch: vi.fn().mockResolvedValue() }),
}));

vi.mock('../setup/useCalendarSetup', () => ({
  useCalendarSetup: () => ({ loadAll: carregaTudo }),
}));

const secao = nome => ({
  props: ['itemId', 'tab'],
  template: `<div data-testid="secao" data-secao="${nome}" :data-item="itemId" :data-tab="tab" />`,
});

const monta = () =>
  shallowMount(CalendarSettingsView, {
    global: {
      stubs: {
        'router-link': { props: ['to'], template: '<a><slot /></a>' },
        SetupHead: true,
        ProceduresSection: secao('procedures'),
        SchedulesSection: secao('availability'),
        ResourcesSection: secao('resources'),
        TeamsSection: secao('teams'),
        CalendarSettingsDialog: {
          props: ['inline', 'tab'],
          template: '<div data-testid="painel" :data-tab="tab" />',
        },
      },
    },
  });

describe('CalendarSettingsView', () => {
  beforeEach(() => {
    rotaAtual.value = { params: { section: 'procedures' } };
    empurra.mockClear();
  });

  it('lista as seis secções do mockup na barra lateral', () => {
    const wrapper = monta();

    [
      'procedures',
      'availability',
      'resources',
      'teams',
      'booking-page',
      'integrations',
    ].forEach(nome => {
      expect(
        wrapper.find(`[data-testid="calendar-settings-nav-${nome}"]`).exists()
      ).toBe(true);
    });
    expect(carregaTudo).toHaveBeenCalled();
  });

  it('abre o procedimento e a aba pedidos pela URL', () => {
    rotaAtual.value = {
      params: { section: 'procedures', itemId: '3', tab: 'when' },
    };

    const secaoAberta = monta().find('[data-testid="secao"]');

    expect(secaoAberta.attributes('data-item')).toBe('3');
    expect(secaoAberta.attributes('data-tab')).toBe('when');
  });

  it('usa o painel antigo para a página de agendamento e integrações', () => {
    rotaAtual.value = { params: { section: 'integrations' } };

    expect(monta().find('[data-testid="painel"]').attributes('data-tab')).toBe(
      'integrations'
    );
  });

  it('cai em procedimentos quando a URL pede uma secção que não existe', () => {
    rotaAtual.value = { params: { section: 'inventada' } };

    expect(monta().find('[data-testid="secao"]').attributes('data-secao')).toBe(
      'procedures'
    );
  });

  it('navega ao clicar numa secção, para a URL poder ser partilhada', async () => {
    const wrapper = monta();

    await wrapper
      .find('[data-testid="calendar-settings-nav-teams"]')
      .trigger('click');

    expect(empurra).toHaveBeenCalledWith(
      '/app/accounts/7/calendar/settings/teams'
    );
  });

  it('marca a secção aberta para quem usa leitor de ecrã', () => {
    const wrapper = monta();

    expect(
      wrapper
        .find('[data-testid="calendar-settings-nav-procedures"]')
        .attributes('aria-current')
    ).toBe('page');
    expect(
      wrapper
        .find('[data-testid="calendar-settings-nav-resources"]')
        .attributes('aria-current')
    ).toBeUndefined();
  });
});
