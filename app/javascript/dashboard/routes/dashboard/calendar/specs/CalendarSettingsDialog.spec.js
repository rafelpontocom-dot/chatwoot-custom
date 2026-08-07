import { flushPromises, shallowMount } from '@vue/test-utils';
import { ref } from 'vue';

import CalendarSettingsDialog from '../CalendarSettingsDialog.vue';
import CalendarAPI from 'dashboard/api/calendar';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

vi.mock('dashboard/composables/store', () => ({
  useMapGetter: () => ref([{ id: 12, name: 'Dra. Ana' }]),
}));

vi.mock('dashboard/api/calendar', () => ({
  default: {
    getProcedures: vi.fn(),
    getResources: vi.fn(),
    updateProcedure: vi.fn(),
    createResource: vi.fn(),
    updateResource: vi.fn(),
  },
}));

const mountDialog = () =>
  shallowMount(CalendarSettingsDialog, {
    global: {
      stubs: {
        Dialog: {
          template: '<div><slot /></div>',
          methods: { open: vi.fn(), close: vi.fn() },
        },
        NextButton: {
          props: ['label'],
          template: '<button v-bind="$attrs">{{ label }}</button>',
        },
        TagMultiSelectComboBox: true,
      },
    },
  });

describe('CalendarSettingsDialog', () => {
  beforeEach(() => {
    CalendarAPI.getProcedures.mockResolvedValue({ data: [] });
    CalendarAPI.getResources.mockResolvedValue({ data: [] });
    CalendarAPI.createResource.mockResolvedValue({
      data: { id: 4, name: 'Dra. Ana', resource_type: 'user', active: true },
    });
  });

  it('creates a professional resource with the selected agent', async () => {
    const wrapper = mountDialog();
    await wrapper.vm.open();
    await flushPromises();

    await wrapper
      .findAll('button')
      .find(button => button.text() === 'CALENDAR.SETTINGS.RESOURCES')
      .trigger('click');
    await wrapper.find('select').setValue('user');
    await wrapper.findAll('select')[1].setValue('12');
    await wrapper.find('form').trigger('submit');
    await flushPromises();

    expect(CalendarAPI.createResource).toHaveBeenCalledWith({
      resource: expect.objectContaining({
        name: 'Dra. Ana',
        resource_type: 'user',
        user_id: 12,
      }),
    });
  });

  it('updates an existing procedure instead of creating a duplicate', async () => {
    CalendarAPI.getProcedures.mockResolvedValue({
      data: [
        {
          id: 7,
          name: 'Consulta inicial',
          duration_minutes: 50,
          recurrence_allowed: false,
          max_sessions: null,
          resource_ids: [],
          active: true,
        },
      ],
    });
    CalendarAPI.updateProcedure.mockResolvedValue({
      data: {
        id: 7,
        name: 'Consulta de avaliação',
        duration_minutes: 60,
        recurrence_allowed: false,
        max_sessions: null,
        resource_ids: [],
        active: true,
      },
    });

    const wrapper = mountDialog();
    await wrapper.vm.open();
    await flushPromises();

    await wrapper
      .find('[data-testid="calendar-edit-procedure"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="calendar-procedure-name"]')
      .setValue('Consulta de avaliação');
    await wrapper
      .find('[data-testid="calendar-procedure-duration"]')
      .setValue('60');
    await wrapper
      .find('[data-testid="calendar-procedure-form"]')
      .trigger('submit');
    await flushPromises();

    expect(CalendarAPI.updateProcedure).toHaveBeenCalledWith(7, {
      procedure: expect.objectContaining({
        name: 'Consulta de avaliação',
        duration_minutes: 60,
      }),
    });
  });

  it('deactivates an existing resource without removing it', async () => {
    CalendarAPI.getResources.mockResolvedValue({
      data: [
        {
          id: 4,
          name: 'Sala 1',
          resource_type: 'room',
          timezone: 'America/Sao_Paulo',
          active: true,
        },
      ],
    });
    CalendarAPI.updateResource.mockResolvedValue({
      data: {
        id: 4,
        name: 'Sala 1',
        resource_type: 'room',
        timezone: 'America/Sao_Paulo',
        active: false,
      },
    });

    const wrapper = mountDialog();
    await wrapper.vm.open();
    await flushPromises();
    await wrapper
      .findAll('button')
      .find(button => button.text() === 'CALENDAR.SETTINGS.RESOURCES')
      .trigger('click');
    await wrapper
      .find('[data-testid="calendar-toggle-resource"]')
      .trigger('click');
    await flushPromises();

    expect(CalendarAPI.updateResource).toHaveBeenCalledWith(4, {
      resource: { active: false },
    });
  });

  it('edits an existing resource without creating another one', async () => {
    CalendarAPI.getResources.mockResolvedValue({
      data: [
        {
          id: 4,
          name: 'Sala 1',
          resource_type: 'room',
          timezone: 'America/Sao_Paulo',
          active: true,
        },
      ],
    });
    CalendarAPI.updateResource.mockResolvedValue({
      data: {
        id: 4,
        name: 'Consultório 1',
        resource_type: 'room',
        timezone: 'America/Sao_Paulo',
        active: true,
      },
    });

    const wrapper = mountDialog();
    await wrapper.vm.open();
    await flushPromises();
    await wrapper
      .findAll('button')
      .find(button => button.text() === 'CALENDAR.SETTINGS.RESOURCES')
      .trigger('click');
    await wrapper
      .find('[data-testid="calendar-edit-resource"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="calendar-resource-name"]')
      .setValue('Consultório 1');
    await wrapper
      .find('[data-testid="calendar-resource-form"]')
      .trigger('submit');
    await flushPromises();

    expect(CalendarAPI.updateResource).toHaveBeenCalledWith(4, {
      resource: expect.objectContaining({
        name: 'Consultório 1',
        resource_type: 'room',
      }),
    });
  });
});
