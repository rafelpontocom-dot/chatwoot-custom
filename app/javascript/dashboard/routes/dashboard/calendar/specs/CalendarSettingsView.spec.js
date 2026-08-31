import { shallowMount } from '@vue/test-utils';
import { ref } from 'vue';

import CalendarSettingsView from '../CalendarSettingsView.vue';

const rotaAtual = ref({ params: { section: 'procedures' } });
const substitui = vi.fn();

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

vi.mock('vue-router', () => ({
  useRoute: () => rotaAtual.value,
  useRouter: () => ({ replace: substitui, push: vi.fn() }),
}));

vi.mock('dashboard/composables/store', () => ({
  useMapGetter: () => ref(7),
  useStore: () => ({ dispatch: vi.fn().mockResolvedValue() }),
}));

const monta = () =>
  shallowMount(CalendarSettingsView, {
    global: {
      stubs: {
        Icon: true,
        'router-link': { props: ['to'], template: '<a><slot /></a>' },
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
    substitui.mockClear();
  });

  it('lista as três secções na navegação lateral', () => {
    const wrapper = monta();

    expect(wrapper.find('[data-testid="calendar-settings-nav"]').exists()).toBe(
      true
    );
    ['procedures', 'resources', 'booking-page'].forEach(secao => {
      expect(
        wrapper.find(`[data-testid="calendar-settings-nav-${secao}"]`).exists()
      ).toBe(true);
    });
  });

  it('entrega ao painel a secção pedida pela URL', () => {
    rotaAtual.value = { params: { section: 'booking-page' } };

    expect(monta().find('[data-testid="painel"]').attributes('data-tab')).toBe(
      'booking-page'
    );
  });

  it('cai em procedimentos quando a URL pede uma secção que não existe', () => {
    rotaAtual.value = { params: { section: 'inventada' } };

    expect(monta().find('[data-testid="painel"]').attributes('data-tab')).toBe(
      'procedures'
    );
  });

  it('navega ao clicar numa secção, para a URL poder ser partilhada', async () => {
    const wrapper = monta();

    await wrapper
      .find('[data-testid="calendar-settings-nav-resources"]')
      .trigger('click');

    expect(substitui).toHaveBeenCalledWith(
      '/app/accounts/7/calendar/settings/resources'
    );
  });

  it('não navega ao clicar na secção que já está aberta', async () => {
    const wrapper = monta();

    await wrapper
      .find('[data-testid="calendar-settings-nav-procedures"]')
      .trigger('click');

    expect(substitui).not.toHaveBeenCalled();
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
