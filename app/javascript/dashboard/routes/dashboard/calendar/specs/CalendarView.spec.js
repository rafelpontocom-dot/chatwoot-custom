import { flushPromises, shallowMount } from '@vue/test-utils';
import { ref } from 'vue';
import CalendarView from '../CalendarView.vue';
import CalendarAPI from 'dashboard/api/calendar';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key => key,
    locale: ref('pt_BR'),
  }),
}));

vi.mock('vue-router', () => ({
  useRoute: () => ({ query: {} }),
}));

vi.mock('dashboard/api/calendar', () => ({
  default: {
    getAppointments: vi.fn(),
    getResources: vi.fn(),
    getProcedures: vi.fn(),
    createAppointment: vi.fn(),
  },
}));

const abrirDialogo = vi.fn();

const mountCalendar = () =>
  shallowMount(CalendarView, {
    global: {
      stubs: {
        KanbanCalendarBookingDialog: {
          setup(_, { expose }) {
            expose({ open: abrirDialogo });
          },
          template: '<div />',
        },
        CalendarAppointmentDetailsDialog: true,
        CalendarSettingsDialog: true,
        // O balão tem spec próprio; aqui só se verifica a ligação com a grade.
        CalendarQuickCreate: {
          props: ['startsAt'],
          emits: ['openFullDialog', 'close'],
          template: `<div v-if="startsAt" data-testid="calendar-quick-create">
            <button data-testid="calendar-quick-more" @click="$emit('openFullDialog')" />
          </div>`,
        },
      },
    },
  });

describe('CalendarView', () => {
  beforeEach(() => {
    CalendarAPI.getAppointments.mockResolvedValue({ data: [] });
    CalendarAPI.getResources.mockResolvedValue({ data: [] });
  });

  it('shows every day of the selected week', async () => {
    const wrapper = mountCalendar();
    await flushPromises();

    expect(wrapper.findAll('[data-testid="calendar-day-column"]')).toHaveLength(
      7
    );
  });

  it('shows a six-week month grid when the user selects month view', async () => {
    const wrapper = mountCalendar();
    await flushPromises();

    await wrapper
      .find('[data-testid="calendar-toolbar-view"]')
      .setValue('month');

    expect(wrapper.findAll('[data-testid="calendar-month-day"]').length).toBe(
      42
    );
  });

  it('shows a month-level heading in month view', async () => {
    const wrapper = mountCalendar();
    await flushPromises();

    await wrapper
      .find('[data-testid="calendar-toolbar-view"]')
      .setValue('month');

    expect(
      wrapper.find('[data-testid="calendar-date-label"]').text()
    ).not.toMatch(/^\d/);
  });

  it('exposes the active calendar view through a labelled select', async () => {
    // Direção A: a vista é um select, como no Google — não um grupo de botões.
    const wrapper = mountCalendar();
    await flushPromises();

    const seletor = wrapper.find('[data-testid="calendar-toolbar-view"]');
    expect(seletor.element.value).toBe('week');
    expect(wrapper.find('label[for="calendar-view-select"]').exists()).toBe(
      true
    );

    await seletor.setValue('month');
    expect(seletor.element.value).toBe('month');
  });

  it('exposes stable controls for the desktop scheduling flow', async () => {
    const wrapper = mountCalendar();
    await flushPromises();

    expect(wrapper.find('[data-testid="calendar-workspace"]').exists()).toBe(
      true
    );
    expect(
      wrapper.find('[data-testid="calendar-new-appointment"]').exists()
    ).toBe(true);
    expect(
      wrapper.find('[data-testid="calendar-open-settings"]').exists()
    ).toBe(true);
  });

  it('uses the full workspace width on desktop', async () => {
    const wrapper = mountCalendar();
    await flushPromises();

    expect(
      wrapper.find('[data-testid="calendar-workspace"]').classes()
    ).toEqual(expect.arrayContaining(['w-full']));
  });

  it('explains that filters or dates may hide appointments after resources exist', async () => {
    CalendarAPI.getResources.mockResolvedValue({
      data: [{ id: 1, name: 'Dra. Ana', active: true }],
    });
    const wrapper = mountCalendar();
    await flushPromises();

    expect(wrapper.text()).toContain('CALENDAR.EMPTY_FILTERED_DESCRIPTION');
  });

  it('keeps the whole toolbar on a single row, like Google Calendar', async () => {
    const wrapper = mountCalendar();
    await flushPromises();

    const barra = wrapper.find('[data-testid="calendar-topbar"]');
    expect(barra.exists()).toBe(true);
    // Uma linha só: antes eram três faixas empilhadas.
    expect(barra.classes()).toEqual(
      expect.arrayContaining(['flex', 'items-center'])
    );
    expect(barra.classes()).not.toContain('flex-wrap');

    [
      'calendar-new-appointment',
      'calendar-toolbar-period',
      'calendar-date-label',
      'calendar-toolbar-search',
      'calendar-toolbar-view',
      'calendar-open-settings',
    ].forEach(id => {
      expect(barra.find(`[data-testid="${id}"]`).exists()).toBe(true);
    });
  });

  it('moves the calendars into a sidebar with a mini month, like Google', async () => {
    CalendarAPI.getResources.mockResolvedValue({
      data: [{ id: 3, name: 'Dra. Ana', active: true }],
    });
    const wrapper = mountCalendar();
    await flushPromises();

    const lateral = wrapper.find('[data-testid="calendar-sidebar"]');
    expect(lateral.exists()).toBe(true);
    // Seis semanas do mini-calendário.
    expect(lateral.findAll('button').length).toBeGreaterThanOrEqual(42);
    expect(lateral.find('[data-testid="calendar-resource-3"]').exists()).toBe(
      true
    );
  });

  it('hides a calendar from the grid when its checkbox is cleared', async () => {
    CalendarAPI.getResources.mockResolvedValue({
      data: [
        { id: 3, name: 'Dra. Ana', active: true },
        { id: 4, name: 'Sala 1', active: true },
      ],
    });
    const wrapper = mountCalendar();
    await flushPromises();
    CalendarAPI.getAppointments.mockClear();

    await wrapper.find('[data-testid="calendar-resource-3"]').setValue(false);
    await flushPromises();

    expect(CalendarAPI.getAppointments).toHaveBeenLastCalledWith(
      expect.objectContaining({ resource_ids: [4] })
    );
  });

  it('filters the calendar by the selected appointment status', async () => {
    const wrapper = mountCalendar();
    await flushPromises();

    await wrapper.find('#calendar-status-filter').setValue('confirmed');
    await flushPromises();

    expect(CalendarAPI.getAppointments).toHaveBeenLastCalledWith(
      expect.objectContaining({ status: 'confirmed' })
    );
  });

  it('keeps appointments outside the default business hours visible', async () => {
    const startsAt = new Date();
    startsAt.setHours(19, 30, 0, 0);
    CalendarAPI.getAppointments.mockResolvedValue({
      data: [
        {
          id: 7,
          starts_at: startsAt.toISOString(),
          contact: { name: 'Ana Silva' },
          procedure: { name: 'Consulta' },
        },
      ],
    });

    const wrapper = mountCalendar();
    await flushPromises();

    expect(
      wrapper.findAll('[data-testid="calendar-appointment"]')
    ).toHaveLength(1);
  });

  it('makes appointments draggable for assisted rescheduling', async () => {
    CalendarAPI.getAppointments.mockResolvedValue({
      data: [
        {
          id: 7,
          starts_at: new Date().toISOString(),
          contact: { name: 'Ana Silva' },
          procedure: { name: 'Consulta' },
        },
      ],
    });

    const wrapper = mountCalendar();
    await flushPromises();

    expect(
      wrapper
        .find('[data-testid="calendar-appointment"]')
        .attributes('draggable')
    ).toBe('true');
  });

  it('shows the appointment status as text on the calendar card', async () => {
    CalendarAPI.getAppointments.mockResolvedValue({
      data: [
        {
          id: 7,
          starts_at: new Date().toISOString(),
          status: 'confirmed',
          contact: { name: 'Ana Silva' },
          procedure: { name: 'Consulta' },
        },
      ],
    });

    const wrapper = mountCalendar();
    await flushPromises();

    expect(
      wrapper.find('[data-testid="calendar-appointment-status"]').text()
    ).toBe('CALENDAR.DETAIL.STATUS.CONFIRMED');
  });

  it('shows the reserved resource on the calendar card', async () => {
    CalendarAPI.getAppointments.mockResolvedValue({
      data: [
        {
          id: 7,
          starts_at: new Date().toISOString(),
          status: 'scheduled',
          contact: { name: 'Ana Silva' },
          procedure: { name: 'Consulta' },
          resources: [{ id: 3, name: 'Dra. Ana' }],
        },
      ],
    });

    const wrapper = mountCalendar();
    await flushPromises();

    expect(
      wrapper.find('[data-testid="calendar-appointment-resource"]').text()
    ).toBe('Dra. Ana');
  });
  it('opens the quick-create popover when an empty slot is clicked', async () => {
    // Direção A: o clique abre um balão ancorado, como no Google. O diálogo
    // inteiro fica atrás de "Mais opções".
    const wrapper = mountCalendar();
    await flushPromises();

    const slots = wrapper.findAll('[data-testid="calendar-slot"]');
    expect(slots.length).toBeGreaterThan(0);

    await slots[0].trigger('click');
    await flushPromises();

    expect(wrapper.find('[data-testid="calendar-quick-create"]').exists()).toBe(
      true
    );
    expect(wrapper.vm.quickSlot).toBeInstanceOf(Date);
    expect(wrapper.vm.quickSlot.getMinutes()).toBe(0);
  });

  it('hands the slot to the full dialog from "more options"', async () => {
    const wrapper = mountCalendar();
    await flushPromises();

    abrirDialogo.mockClear();

    await wrapper.findAll('[data-testid="calendar-slot"]')[0].trigger('click');
    await flushPromises();
    await wrapper.find('[data-testid="calendar-quick-more"]').trigger('click');

    expect(abrirDialogo).toHaveBeenCalledTimes(1);
    expect(abrirDialogo.mock.calls[0][0].startsAt).toBeInstanceOf(Date);
    // O balão fecha ao passar a vez para o diálogo.
    expect(wrapper.find('[data-testid="calendar-quick-create"]').exists()).toBe(
      false
    );
  });
});
