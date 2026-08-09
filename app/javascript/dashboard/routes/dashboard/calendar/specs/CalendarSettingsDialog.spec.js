import { flushPromises, shallowMount } from '@vue/test-utils';
import { ref } from 'vue';

import CalendarSettingsDialog from '../CalendarSettingsDialog.vue';
import CalendarAPI from 'dashboard/api/calendar';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

vi.mock('dashboard/composables/store', () => ({
  useMapGetter: key =>
    ref(key === 'agents/getAgents' ? [{ id: 12, name: 'Dra. Ana' }] : []),
  useStore: () => ({ dispatch: vi.fn().mockResolvedValue() }),
}));

vi.mock('dashboard/api/calendar', () => ({
  default: {
    getProcedures: vi.fn(),
    getResources: vi.fn(),
    getBookingPage: vi.fn(),
    getBookingLinks: vi.fn(),
    getGoogleCalendarConnection: vi.fn(),
    getGoogleCalendarAuthorizationUrl: vi.fn(),
    disconnectGoogleCalendar: vi.fn(),
    retryGoogleCalendar: vi.fn(),
    updateBookingPage: vi.fn(),
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
    CalendarAPI.getGoogleCalendarConnection.mockResolvedValue({
      data: { connected: false, status: 'disconnected' },
    });
    CalendarAPI.retryGoogleCalendar.mockResolvedValue({
      data: { connected: true, status: 'connected', retryable: false },
    });
    CalendarAPI.createResource.mockResolvedValue({
      data: { id: 4, name: 'Dra. Ana', resource_type: 'user', active: true },
    });
  });

  it('exposes configuration sections as accessible tabs', async () => {
    const wrapper = mountDialog();
    await wrapper.vm.open();
    await flushPromises();

    const tabs = wrapper.findAll('[role="tab"]');

    expect(tabs).toHaveLength(3);
    expect(tabs[0].attributes('aria-selected')).toBe('true');
    expect(tabs[0].attributes('aria-controls')).toBe(
      'calendar-settings-procedures-panel'
    );
  });

  it('loads the booking page only when its configuration tab is selected', async () => {
    const wrapper = mountDialog();
    await wrapper.vm.open();
    await flushPromises();

    expect(CalendarAPI.getBookingPage).not.toHaveBeenCalled();

    await wrapper
      .findAll('[role="tab"]')
      .find(tab => tab.text() === 'CALENDAR.SETTINGS.BOOKING_PAGE')
      .trigger('click');
    await flushPromises();

    expect(CalendarAPI.getBookingPage).toHaveBeenCalled();
    expect(
      wrapper.find('[data-testid="calendar-booking-page-form"]').exists()
    ).toBe(true);
  });

  it('keeps procedure creation out of the list until requested', async () => {
    const wrapper = mountDialog();
    await wrapper.vm.open();
    await flushPromises();

    expect(
      wrapper.find('[data-testid="calendar-procedure-form"]').exists()
    ).toBe(false);

    await wrapper
      .find('[data-testid="calendar-add-procedure"]')
      .trigger('click');

    expect(
      wrapper.find('[data-testid="calendar-procedure-form"]').exists()
    ).toBe(true);
  });

  it('creates a professional resource with the selected agent', async () => {
    const wrapper = mountDialog();
    await wrapper.vm.open();
    await flushPromises();

    await wrapper
      .findAll('button')
      .find(button => button.text() === 'CALENDAR.SETTINGS.RESOURCES')
      .trigger('click');
    await wrapper
      .find('[data-testid="calendar-add-resource"]')
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

  it('loads Google Calendar status only when editing an agenda', async () => {
    CalendarAPI.getResources.mockResolvedValue({
      data: [
        {
          id: 8,
          name: 'Agenda da Dra. Ana',
          resource_type: 'generic',
          user_id: null,
          active: true,
        },
      ],
    });
    const wrapper = mountDialog();
    await wrapper.vm.open();
    await flushPromises();

    await wrapper
      .findAll('[role="tab"]')
      .find(tab => tab.text() === 'CALENDAR.SETTINGS.RESOURCES')
      .trigger('click');
    await flushPromises();
    await wrapper
      .find('[data-testid="calendar-edit-resource"]')
      .trigger('click');
    await flushPromises();

    expect(CalendarAPI.getGoogleCalendarConnection).toHaveBeenCalledWith(8);
    expect(wrapper.text()).toContain(
      'CALENDAR.SETTINGS.GOOGLE_CALENDAR.DISCONNECTED'
    );
  });

  it('reprocesses an agenda after a recoverable Google Calendar error', async () => {
    CalendarAPI.getResources.mockResolvedValue({
      data: [
        {
          id: 8,
          name: 'Agenda da Dra. Ana',
          resource_type: 'generic',
          user_id: null,
          active: true,
        },
      ],
    });
    CalendarAPI.getGoogleCalendarConnection.mockResolvedValue({
      data: {
        connected: false,
        retryable: true,
        status: 'error',
        last_error: 'Google timeout',
      },
    });
    const wrapper = mountDialog();
    await wrapper.vm.open();
    await flushPromises();

    await wrapper
      .findAll('[role="tab"]')
      .find(tab => tab.text() === 'CALENDAR.SETTINGS.RESOURCES')
      .trigger('click');
    await wrapper
      .find('[data-testid="calendar-edit-resource"]')
      .trigger('click');
    await flushPromises();
    await wrapper
      .find('[data-testid="calendar-retry-google-calendar"]')
      .trigger('click');
    await flushPromises();

    expect(CalendarAPI.retryGoogleCalendar).toHaveBeenCalledWith(8);
    expect(wrapper.text()).toContain(
      'CALENDAR.SETTINGS.GOOGLE_CALENDAR.CONNECTED'
    );
  });

  it('updates an existing procedure instead of creating a duplicate', async () => {
    CalendarAPI.getProcedures.mockResolvedValue({
      data: [
        {
          id: 7,
          name: 'Consulta inicial',
          duration_minutes: 50,
          buffer_before_minutes: 10,
          buffer_after_minutes: 15,
          location_type: 'video',
          color: '#00B8C6',
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
        buffer_before_minutes: 10,
        buffer_after_minutes: 15,
        location_type: 'video',
        color: '#00B8C6',
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
        buffer_before_minutes: 10,
        buffer_after_minutes: 15,
        location_type: 'video',
      }),
    });
  });

  it('uses a recurrence limit when enabling recurrence for an existing procedure', async () => {
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
        name: 'Consulta inicial',
        duration_minutes: 50,
        recurrence_allowed: true,
        max_sessions: 10,
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
      .find('[data-testid="calendar-procedure-recurrence"]')
      .setValue(true);
    await wrapper
      .find('[data-testid="calendar-procedure-form"]')
      .trigger('submit');
    await flushPromises();

    expect(CalendarAPI.updateProcedure).toHaveBeenCalledWith(7, {
      procedure: expect.objectContaining({
        recurrence_allowed: true,
        max_sessions: 10,
      }),
    });
  });

  it('publishes a procedure with its public title and booking slug', async () => {
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
          public_booking_enabled: false,
        },
      ],
    });
    CalendarAPI.updateProcedure.mockResolvedValue({ data: {} });

    const wrapper = mountDialog();
    await wrapper.vm.open();
    await flushPromises();

    await wrapper
      .find('[data-testid="calendar-edit-procedure"]')
      .trigger('click');
    await wrapper
      .find('[data-testid="calendar-procedure-public-enabled"]')
      .setValue(true);
    await wrapper
      .find('[data-testid="calendar-procedure-public-slug"]')
      .setValue('consulta-inicial');
    await wrapper
      .find('[data-testid="calendar-procedure-form"]')
      .trigger('submit');
    await flushPromises();

    expect(CalendarAPI.updateProcedure).toHaveBeenCalledWith(7, {
      procedure: expect.objectContaining({
        public_booking_enabled: true,
        public_slug: 'consulta-inicial',
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
