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
    createResource: vi.fn(),
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
});
