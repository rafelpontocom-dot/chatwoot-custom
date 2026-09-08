import { flushPromises, mount } from '@vue/test-utils';
import RaevoAiAPI from 'dashboard/api/raevoAi';
import RaevoAiServiceHoursSettings from '../RaevoAiServiceHoursSettings.vue';

vi.mock('dashboard/api/raevoAi', () => ({
  default: {
    getServiceHours: vi.fn(),
    saveServiceHours: vi.fn(),
  },
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const mountComponent = () =>
  mount(RaevoAiServiceHoursSettings, {
    global: {
      stubs: {
        RaevoField: {
          template:
            '<div><slot control-class="control" field-id="field" described-by="hint" /></div>',
        },
        NextButton: {
          emits: ['click'],
          template:
            '<button v-bind="$attrs" type="button" @click="$emit(\'click\')"><slot /></button>',
        },
      },
    },
  });

describe('RaevoAiServiceHoursSettings', () => {
  beforeEach(() => {
    RaevoAiAPI.getServiceHours.mockResolvedValue({
      data: {
        config: {
          enabled: true,
          timezone: 'America/Sao_Paulo',
          windows: [{ days: [1, 2, 3, 4, 5], start: '08:00', end: '18:00' }],
          revision: 2,
          source: 'structured',
        },
      },
    });
    RaevoAiAPI.saveServiceHours.mockResolvedValue({
      data: {
        config: {
          enabled: true,
          timezone: 'America/Sao_Paulo',
          windows: [{ days: [1, 2, 3, 4, 5], start: '08:00', end: '18:00' }],
          revision: 3,
          source: 'structured',
        },
      },
    });
  });

  it('shows one explicit operational row for every weekday', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    expect(
      wrapper.findAll('[data-testid="ai-service-hours-day"]')
    ).toHaveLength(7);
    expect(
      wrapper.get('[data-testid="ai-service-hours-enabled"]').element.checked
    ).toBe(true);
  });

  it('saves a compact revision-guarded schedule through the Chatwoot BFF', async () => {
    const wrapper = mountComponent();
    await flushPromises();
    await wrapper.get('[data-testid="ai-service-hours-save"]').trigger('click');
    await flushPromises();

    expect(RaevoAiAPI.saveServiceHours).toHaveBeenCalledWith({
      expected_revision: 2,
      config: {
        enabled: true,
        timezone: 'America/Sao_Paulo',
        windows: [{ days: [1, 2, 3, 4, 5], start: '08:00', end: '18:00' }],
      },
    });
  });

  it('does not require weekday windows when the tenant chooses 24-hour service', async () => {
    const wrapper = mountComponent();
    await flushPromises();
    await wrapper
      .get('[data-testid="ai-service-hours-enabled"]')
      .setValue(false);
    await wrapper.get('[data-testid="ai-service-hours-save"]').trigger('click');
    await flushPromises();

    expect(RaevoAiAPI.saveServiceHours).toHaveBeenCalledWith({
      expected_revision: 2,
      config: {
        enabled: false,
        timezone: 'America/Sao_Paulo',
        windows: [],
      },
    });
  });
});
