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

const empurraRota = vi.fn();
const trocaRota = vi.fn();
const rota = vi.hoisted(() => ({ query: {} }));

vi.mock('vue-router', () => ({
  useRoute: () => rota,
  useRouter: () => ({ push: empurraRota, replace: trocaRota }),
}));

vi.mock('dashboard/api/calendar', () => ({
  default: {
    getAppointments: vi.fn(),
    getBusyBlocks: vi.fn(),
    getResources: vi.fn(),
    getProcedures: vi.fn(),
    createAppointment: vi.fn(),
  },
}));

const abrirDialogo = vi.fn();
const abrirDetalhes = vi.fn();
const abrirRemarcacao = vi.fn();

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
        CalendarAppointmentDetailsDialog: {
          setup(_, { expose }) {
            expose({ open: abrirDetalhes, openForReschedule: abrirRemarcacao });
          },
          template: '<div />',
        },
        // O balão do evento tem spec próprio; aqui verifica-se só a ligação.
        CalendarEventPopover: {
          props: ['appointment'],
          emits: ['openDetails', 'cancel', 'reschedule', 'close'],
          template: `<div v-if="appointment" data-testid="calendar-event-popover">
            <button data-testid="popover-detalhes" @click="$emit('openDetails')" />
            <button data-testid="popover-remarcar" @click="$emit('reschedule')" />
          </div>`,
        },
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
  // Um teste que pare o relógio não o deixa parado para os seguintes, mesmo
  // que falhe a meio.
  afterEach(() => {
    vi.useRealTimers();
  });

  beforeEach(() => {
    rota.query = {};
    CalendarAPI.getAppointments.mockResolvedValue({ data: [] });
    CalendarAPI.getBusyBlocks.mockResolvedValue({ data: [] });
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

    // O profissional passou a partilhar linha com o procedimento, por isso o
    // separador vem junto; o que o teste garante é que continua visível.
    expect(
      wrapper.find('[data-testid="calendar-appointment-resource"]').text()
    ).toContain('Dra. Ana');
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

  it('opens the anchored popover, not the dialog, when an appointment is clicked', async () => {
    // A queixa era o diálogo de 543 linhas a abrir por cima da agenda. Agora o
    // clique responde no sítio, e o diálogo fica atrás do ⋮.
    //
    // O relógio fica parado na semana da consulta. A agenda abre na semana de
    // hoje; com a data da consulta fixa e o relógio a andar, o teste passou
    // enquanto 31/08 estava na semana corrente e partiu sozinho em setembro.
    // Só a data é falsa: timers falsos travariam o `flushPromises`.
    vi.useFakeTimers({ toFake: ['Date'] });
    vi.setSystemTime(new Date('2026-08-31T08:00:00.000Z'));
    CalendarAPI.getAppointments.mockResolvedValue({
      data: [
        {
          id: 9,
          starts_at: '2026-08-31T09:00:00.000Z',
          ends_at: '2026-08-31T09:50:00.000Z',
          status: 'scheduled',
          contact: { id: 3, name: 'Maria Silva' },
          procedure: { id: 4, name: 'Toxina' },
          resources: [],
        },
      ],
    });

    const wrapper = mountCalendar();
    await flushPromises();
    abrirDetalhes.mockClear();

    await wrapper.find('[data-testid="calendar-appointment"]').trigger('click');
    await flushPromises();

    expect(
      wrapper.find('[data-testid="calendar-event-popover"]').exists()
    ).toBe(true);
    expect(abrirDetalhes).not.toHaveBeenCalled();

    await wrapper.find('[data-testid="popover-detalhes"]').trigger('click');
    expect(abrirDetalhes).toHaveBeenCalledWith(9);
    // O balão sai de cena ao passar a vez ao diálogo.
    expect(
      wrapper.find('[data-testid="calendar-event-popover"]').exists()
    ).toBe(false);
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

  it('mostra "todas as situações" escolhido, em vez de uma pílula vazia', async () => {
    // A opção vale "all"; começar em "" deixava o select sem nada selecionado
    // e o filtro parecia partido.
    const wrapper = mountCalendar();
    await flushPromises();

    expect(wrapper.vm.selectedStatus).toBe('all');
  });

  it('nomeia os dias da semana no cabeçalho do mês, em vez de datas', async () => {
    const wrapper = mountCalendar();
    await flushPromises();

    wrapper.vm.view = 'month';
    await flushPromises();

    // Deriva-se da própria coluna, por isso nunca desalinha do que está por baixo.
    const rotulo = wrapper.vm.monthWeekdayLabel(0);
    expect(rotulo).toBeTruthy();
    expect(rotulo).not.toMatch(/\d/);
  });

  const consulta = (id, inicio, fim, extra = {}) => ({
    id,
    starts_at: inicio,
    ends_at: fim,
    status: 'scheduled',
    contact: { id: 1, name: 'Maria Silva' },
    procedure: { id: 2, name: 'Toxina' },
    resources: [],
    ...extra,
  });

  it('dá a cada consulta altura proporcional à duração', async () => {
    CalendarAPI.getAppointments.mockResolvedValue({
      data: [
        consulta(1, '2026-08-31T09:00:00.000Z', '2026-08-31T09:50:00.000Z'),
        consulta(2, '2026-08-31T13:00:00.000Z', '2026-08-31T15:30:00.000Z'),
      ],
    });

    const wrapper = mountCalendar();
    await flushPromises();

    const dia = new Date('2026-08-31T09:00:00.000Z');
    const curta = wrapper.vm.appointmentsForSlot(dia, dia.getHours())[0];
    const longa = wrapper.vm.appointmentsForSlot(
      dia,
      new Date('2026-08-31T13:00:00.000Z').getHours()
    )[0];

    // A célula é uma hora, por isso a altura é a duração em percentagem dela.
    expect(curta.estilo.height).toBe(`${(50 / 60) * 100}%`);
    expect(longa.estilo.height).toBe(`${(150 / 60) * 100}%`);
  });

  it('desloca a consulta que não começa à hora certa', async () => {
    CalendarAPI.getAppointments.mockResolvedValue({
      data: [
        consulta(1, '2026-08-31T09:30:00.000Z', '2026-08-31T10:00:00.000Z'),
      ],
    });

    const wrapper = mountCalendar();
    await flushPromises();

    const dia = new Date('2026-08-31T09:30:00.000Z');
    const [entrada] = wrapper.vm.appointmentsForSlot(dia, dia.getHours());

    expect(entrada.estilo.top).toBe('50%');
  });

  it('põe lado a lado as consultas que se sobrepõem', async () => {
    CalendarAPI.getAppointments.mockResolvedValue({
      data: [
        consulta(1, '2026-08-31T10:00:00.000Z', '2026-08-31T11:30:00.000Z'),
        consulta(2, '2026-08-31T10:30:00.000Z', '2026-08-31T11:30:00.000Z'),
        consulta(3, '2026-08-31T10:45:00.000Z', '2026-08-31T11:00:00.000Z'),
      ],
    });

    const wrapper = mountCalendar();
    await flushPromises();

    const dia = new Date('2026-08-31T10:00:00.000Z');
    const entradas = wrapper.vm.appointmentsForSlot(dia, dia.getHours());

    // Três a disputar o mesmo espaço: um terço da largura cada, sem se taparem.
    const larguras = entradas.map(item => item.estilo.width);
    expect(larguras).toEqual([`${100 / 3}%`, `${100 / 3}%`, `${100 / 3}%`]);
    expect(entradas.map(item => item.estilo.left)).toEqual([
      '0%',
      `${100 / 3}%`,
      `${(100 / 3) * 2}%`,
    ]);
  });

  it('devolve a largura toda a quem não disputa espaço com ninguém', async () => {
    CalendarAPI.getAppointments.mockResolvedValue({
      data: [
        consulta(1, '2026-08-31T09:00:00.000Z', '2026-08-31T10:00:00.000Z'),
        // Começa exatamente quando a anterior acaba: não há sobreposição.
        consulta(2, '2026-08-31T10:00:00.000Z', '2026-08-31T11:00:00.000Z'),
      ],
    });

    const wrapper = mountCalendar();
    await flushPromises();

    const dia = new Date('2026-08-31T09:00:00.000Z');
    const [primeira] = wrapper.vm.appointmentsForSlot(dia, dia.getHours());

    expect(primeira.estilo.width).toBe('100%');
    expect(primeira.estilo.left).toBe('0%');
  });

  it('mostra só a primeira linha numa consulta curta', async () => {
    CalendarAPI.getAppointments.mockResolvedValue({
      data: [
        consulta(1, '2026-08-31T09:00:00.000Z', '2026-08-31T09:20:00.000Z'),
      ],
    });

    const wrapper = mountCalendar();
    await flushPromises();

    const dia = new Date('2026-08-31T09:00:00.000Z');
    expect(
      wrapper.vm.appointmentsForSlot(dia, dia.getHours())[0].compacto
    ).toBe(true);
  });

  it('não encolhe o cartão por não saber a duração', async () => {
    // Sem data de fim desenha-se meia hora, mas isso é palpite: esconder o
    // profissional e a situação por falta de um dado seria perder informação.
    CalendarAPI.getAppointments.mockResolvedValue({
      data: [consulta(1, '2026-08-31T09:00:00.000Z', undefined)],
    });

    const wrapper = mountCalendar();
    await flushPromises();

    const dia = new Date('2026-08-31T09:00:00.000Z');
    expect(
      wrapper.vm.appointmentsForSlot(dia, dia.getHours())[0].compacto
    ).toBe(false);
  });

  it('estica a grade até ao fim da última consulta, não ao seu início', async () => {
    CalendarAPI.getAppointments.mockResolvedValue({
      data: [
        consulta(1, '2026-08-31T17:00:00.000Z', '2026-08-31T19:00:00.000Z'),
      ],
    });

    const wrapper = mountCalendar();
    await flushPromises();

    const ultima = wrapper.vm.hourSlots[wrapper.vm.hourSlots.length - 1];
    expect(ultima).toBeGreaterThanOrEqual(
      new Date('2026-08-31T19:00:00.000Z').getHours() - 1
    );
  });

  describe('compromissos da agenda Google', () => {
    const quartaAs = (hora, minuto = 0) =>
      new Date(2026, 8, 16, hora, minuto).toISOString();
    const bloqueio = (id, inicio, fim, extra = {}) => ({
      id,
      resource_id: 3,
      starts_at: inicio,
      ends_at: fim,
      all_day: false,
      source: 'google_calendar',
      ...extra,
    });

    beforeEach(() => {
      vi.useFakeTimers({ toFake: ['Date'] });
      vi.setSystemTime(new Date(2026, 8, 16, 9, 0));
      CalendarAPI.getResources.mockResolvedValue({
        data: [{ id: 3, name: 'Dra. Ana', active: true }],
      });
    });

    // Google e Feegow ocupam a mesma grade: quem lê precisa de saber de onde veio.
    it('diz de que agenda veio cada horário ocupado', async () => {
      CalendarAPI.getBusyBlocks.mockResolvedValue({
        data: [
          bloqueio(40, quartaAs(10), quartaAs(11)),
          bloqueio(41, quartaAs(15), quartaAs(16), { source: 'feegow' }),
        ],
      });

      const wrapper = mountCalendar();
      await flushPromises();

      const textos = wrapper
        .findAll('[data-testid="calendar-busy-block"]')
        .map(bloco => bloco.text());
      expect(textos[0]).toContain('CALENDAR.BUSY.SOURCE.GOOGLE_CALENDAR');
      expect(textos[1]).toContain('CALENDAR.BUSY.SOURCE.FEEGOW');
    });

    it('pede os horários ocupados do mesmo período e os desenha como ocupado', async () => {
      CalendarAPI.getBusyBlocks.mockResolvedValue({
        data: [bloqueio(40, quartaAs(10), quartaAs(11, 30))],
      });

      const wrapper = mountCalendar();
      await flushPromises();

      const [pedido] = CalendarAPI.getBusyBlocks.mock.calls.at(-1);
      const [pedidoConsultas] = CalendarAPI.getAppointments.mock.calls.at(-1);
      expect(pedido.starts_at).toBe(pedidoConsultas.starts_at);
      expect(pedido.ends_at).toBe(pedidoConsultas.ends_at);

      const bloco = wrapper.find('[data-testid="calendar-busy-block"]');
      expect(bloco.text()).toContain('CALENDAR.BUSY.SOURCE.GOOGLE_CALENDAR');
      expect(bloco.text()).toContain('Dra. Ana');
      // Não é um botão: não se abre nem se arrasta o que é do Google.
      expect(bloco.element.tagName).not.toBe('BUTTON');
    });

    it('divide a largura com a consulta com que se sobrepõe', async () => {
      CalendarAPI.getAppointments.mockResolvedValue({
        data: [consulta(1, quartaAs(10), quartaAs(11))],
      });
      CalendarAPI.getBusyBlocks.mockResolvedValue({
        data: [bloqueio(40, quartaAs(10, 30), quartaAs(11, 30))],
      });

      const wrapper = mountCalendar();
      await flushPromises();

      const dia = new Date(2026, 8, 16);
      const [daConsulta] = wrapper.vm.appointmentsForSlot(dia, 10);
      const [doGoogle] = wrapper.vm.busyBlocksForSlot(dia, 10);
      expect(daConsulta.estilo).toMatchObject({ width: '50%', left: '0%' });
      expect(doGoogle.estilo).toMatchObject({
        width: '50%',
        left: '50%',
        top: '50%',
      });
    });

    it('põe o dia inteiro ocupado no cabeçalho do dia, não na grade', async () => {
      CalendarAPI.getBusyBlocks.mockResolvedValue({
        data: [
          bloqueio(41, quartaAs(0), new Date(2026, 8, 17).toISOString(), {
            all_day: true,
          }),
        ],
      });

      const wrapper = mountCalendar();
      await flushPromises();

      expect(wrapper.find('[data-testid="calendar-busy-block"]').exists()).toBe(
        false
      );
      const colunas = wrapper.findAll('[data-testid="calendar-day-column"]');
      const quarta = colunas.find(coluna =>
        coluna.find('[data-testid="calendar-busy-all-day"]').exists()
      );
      const etiqueta = quarta.find('[data-testid="calendar-busy-all-day"]');
      expect(etiqueta.text()).toContain('CALENDAR.BUSY.ALL_DAY_SHORT');
      expect(etiqueta.attributes('aria-label')).toBe(
        'CALENDAR.BUSY.ALL_DAY_ARIA'
      );
    });
  });

  it('avisa, ao voltar do Google, que a permissão da agenda não foi dada', async () => {
    rota.query = { google_calendar: 'permission_denied' };

    const wrapper = mountCalendar();
    await flushPromises();

    const aviso = wrapper.find('[data-testid="calendar-google-notice"]');
    expect(aviso.text()).toContain('CALENDAR.GOOGLE_NOTICE.PERMISSION_DENIED');

    await aviso
      .find('[data-testid="calendar-google-notice-dismiss"]')
      .trigger('click');
    expect(trocaRota).toHaveBeenCalledWith({ query: {} });
  });
});
